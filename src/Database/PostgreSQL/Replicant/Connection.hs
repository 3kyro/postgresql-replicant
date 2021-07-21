{-
Module : Database.PostgreSQL.Replicant.Connection
Description : Create replication handling connections to PostgreSQL

A ReplicantConnection is different from a regular Connection because
it uses a special mode that can send replication commands that regular
Connection objects cannots send.
-}
module Database.PostgreSQL.Replicant.Connection
  ( -- * Types
    ReplicantConnection
    -- * Constructor
  , connect
  , getConnection
  )
where

import Control.Concurrent
import Control.Exception
import Database.PostgreSQL.LibPQ
import Network.Socket.KeepAlive
import System.Posix.Types

import Database.PostgreSQL.Replicant.Exception
import Database.PostgreSQL.Replicant.Settings
import Database.PostgreSQL.Replicant.Util

newtype ReplicantConnection
  = ReplicantConnection { getConnection :: Connection }
  deriving Eq

data ConnectResult
  = ConnectSuccess
  | ConnectFailure
  deriving (Eq, Show)

-- | Connect to the PostgreSQL server in replication mode
connect :: PgSettings -> IO ReplicantConnection
connect settings = do
  conn <- connectStart $ pgConnectionString settings
  mFd <- socket conn
  sockFd <- maybeThrow
    (ReplicantException "withLogicalStream: could not get socket fd") mFd
  pollResult <- pollConnectStart conn sockFd
  case pollResult of
    ConnectFailure -> throwIO
      $ ReplicantException "withLogicalStream: Unable to connect to the database"
    ConnectSuccess -> pure $ ReplicantConnection conn

pollConnectStart :: Connection -> Fd -> IO ConnectResult
pollConnectStart conn fd@(Fd cint) = do
  pollStatus <- connectPoll conn
  case pollStatus of
    PollingReading -> do
      threadWaitRead fd
      pollConnectStart conn fd
    PollingWriting -> do
      threadWaitWrite fd
      pollConnectStart conn fd
    PollingOk -> do
      _ <- setKeepAlive cint $ KeepAlive True 60 2
      pure ConnectSuccess
    PollingFailed -> pure ConnectFailure
