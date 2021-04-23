module Database.PostgreSQL.Replicant.Queue where

import Control.Concurrent.MVar
import Data.Sequence (Seq, ViewR (..), (<|), (|>))
import qualified Data.Sequence as S

newtype FifoQueue a = FifoQueue (MVar (Seq a))

empty :: IO (FifoQueue a)
empty = FifoQueue <$> newMVar S.empty

-- | Return @True@ if the queue is empty
null :: FifoQueue a -> IO Bool
null (FifoQueue mQueue) = do
  queue <- readMVar mQueue
  pure $ S.null queue

-- | Remove an item from the end of the non-empty queue.
dequeue :: FifoQueue a -> IO (Maybe a)
dequeue (FifoQueue mQueue) = do
  queue <- takeMVar mQueue
  case S.viewr queue of
    S.EmptyR -> do
      putMVar mQueue queue
      pure Nothing
    rest :> x -> do
      putMVar mQueue rest
      pure $ Just x

-- | Put an item on the front of the queue.
enqueue :: FifoQueue a -> a -> IO ()
enqueue (FifoQueue mQueue) x = do
  queue <- takeMVar mQueue
  putMVar mQueue $ x <| queue

-- | Put an item on the end of the queue so that it will be dequeued first.
enqueueRight :: FifoQueue a -> a -> IO ()
enqueueRight (FifoQueue mQueue) x = do
  queue <- takeMVar mQueue
  putMVar mQueue $ queue |> x
