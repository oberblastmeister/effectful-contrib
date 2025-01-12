{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE Strict #-}
{-|
  Module      : Effectful.Cache
  Copyright   : © Hécate Moonlight, 2021
  License     : MIT
  Maintainer  : hecate@glitchbra.in
  Stability   : stable

  An effect wrapper around Data.Cache for the Effectful ecosystem
-}
module Effectful.Cache
  ( -- * The /Cache/ effect
    Cache(..)
    -- * Handlers
  , runCacheIO
    -- * Cache operations
  , insert
  , lookup
  , keys
  , delete
  , filterWithKey
  ) where

import Control.Monad.IO.Class
import Data.Hashable
import Data.Kind
import Effectful.Dispatch.Dynamic
import Effectful.Monad
import Prelude hiding (lookup)
import qualified Data.Cache as C

-- | Operations on a cache
-- Since it is an effect with type variables, you will have the duty of making unambiguous calls to the provided
-- functions. This means that with numerical literals ('3', '4', etc), visible type applications will be necessary.
-- See each function's documentation for examples.
data Cache k v :: Effect where
  Insert :: (Eq k, Hashable k) => k -> v -> Cache k v m ()
  Lookup :: (Eq k, Hashable k) => k -> Cache k v m (Maybe v)
  Keys :: Cache k v m [k]
  Delete :: (Eq k, Hashable k) => k -> Cache k v m ()
  FilterWithKey :: (Eq k, Hashable k) => (k -> v -> Bool) -> Cache k v m ()

type instance DispatchOf (Cache k v) = 'Dynamic

-- | The default IO handler
runCacheIO :: forall (k :: Type) (v :: Type) (es :: [Effect]) (a :: Type)
            . (Eq k, Hashable k, IOE :> es)
           => C.Cache k v
           -> Eff (Cache k v : es) a
           -> Eff es a
runCacheIO cache = interpret $ \_ -> \case
  Insert key value  -> liftIO $ C.insert cache key value
  Lookup key        -> liftIO $ C.lookup cache key
  Keys              -> liftIO $ C.keys cache
  Delete key        -> liftIO $ C.delete cache key
  FilterWithKey fun -> liftIO $ C.filterWithKey fun cache

-- | Insert an item in the cache, using the default expiration value of the cache.
insert :: forall (k :: Type) (v :: Type) (es :: [Effect])
        . (Eq k, Hashable k, Cache k v :> es)
       => k -> v -> Eff es ()
insert key value = send $ Insert key value

-- | Lookup an item with the given key, and delete it if it is expired.
--
-- The function will only return a value if it is present in the cache and if the item is not expired.
-- The function will eagerly delete the item from the cache if it is expired.
lookup :: forall (k :: Type) (v :: Type) (es :: [Effect])
        . (Eq k, Hashable k, Cache k v :> es)
       => k -> Eff es (Maybe v)
lookup key = send $ Lookup key

-- | List all the keys of the cache.
--
-- Since 'Cache' has type variables, you will need to use visible type applications or explicitly typed
-- arguments for the key *and* value parameters to distinguish this 'Cache' from potentially other ones.
--
-- === __Example__
--
-- > listKeys :: (Cache Int Int :> es) => Eff es [Int]
-- > listKeys = do
-- >   mapM_ (\(k,v) -> insert @Int @Int k v) [(2,4),(3,6),(4,8),(5,10)]
-- >   keys @Int @Int -- [2,3,4,5]
keys :: forall (k :: Type) (v :: Type) (es :: [Effect])
      . (Cache k v :> es) => Eff es [k]
keys = send @(Cache k v) Keys

-- | Delete the provided key from the cache it is present.
--
-- Since 'Cache' has type variables, you will need to use visible type applications or explicitly typed
-- arguments for the key *and* value parameters to distinguish this 'Cache' from potentially other ones.
--
-- === __Example__
--
-- > deleteKeys :: (Cache Int Int :> es) => Eff es [Int]
-- > deleteKeys = do
-- >   mapM_ (\(k,v) -> insert @Int @Int k v) [(2,4),(3,6),(4,8),(5,10)]
-- >   delete @Int @Int 3
-- >   delete @Int @Int 5
-- >   keys @Int @Int -- [2,4]
delete :: forall (k :: Type) (v :: Type) (es :: [Effect])
        . (Eq k, Hashable k, Cache k v :> es)
      => k -> Eff es ()
delete key = send @(Cache k v) $ Delete key

-- | Keeps elements that satisfy the predicate (used for cache invalidation).
--
-- Note that the predicate might be called for expired items.
--
-- Since 'Cache' has type variables, you will need to use visible type applications or explicitly typed
-- arguments for the key *and* value parameters to distinguish this 'Cache' from potentially other ones.
--
-- === __Example__
--
-- > filterKeys :: (Cache Int Int :> es) => Eff es [Int]
-- > filterKeys = do
-- >   mapM_ (\(k,v) -> insert @Int @Int k v) [(2,4),(3,6),(4,8),(5,10)]
-- >   filterWithKey @Int @Int (\k _ -> k /= 3)
-- >   keys @Int @Int -- [2,4,5]
filterWithKey :: forall (k :: Type) (v :: Type) (es :: [Effect])
               . (Eq k, Hashable k, Cache k v :> es)
              => (k -> v -> Bool) -> Eff es ()
filterWithKey fun = send $ FilterWithKey fun

