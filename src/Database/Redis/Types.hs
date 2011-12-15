{-# LANGUAGE FlexibleInstances, UndecidableInstances, OverlappingInstances, TypeSynonymInstances #-}

module Database.Redis.Types where

import Control.Applicative
import Control.Monad
import Data.ByteString.Char8 (ByteString, unpack)
import Data.Maybe
import qualified Data.Map as Map
import qualified Data.Set as Set
import Database.Redis.Reply


------------------------------------------------------------------------------
-- Classes of types Redis understands
--
class RedisStatus a where
    decodeStatus :: Reply -> Maybe a

class RedisBool a where
    decodeBool :: Reply -> Maybe a

class RedisInt a where
    decodeInt :: Reply -> Maybe a

class RedisKey a where
    decodeKey :: Reply -> Maybe a

class RedisString a where
    decodeString :: Reply -> Maybe a

class RedisList a where
    decodeList :: Reply -> Maybe a

class RedisSet a where
    decodeSet :: Reply -> Maybe a

class RedisHash a where
    decodeHash :: Reply -> Maybe a

class RedisPair a where
    decodePair :: Reply -> Maybe a


------------------------------------------------------------------------------
-- RediStatus instances
--
data Status = Ok | Pong | None | String | Hash | List | Set | ZSet
    deriving (Show, Eq)

instance RedisStatus ByteString where
    decodeStatus (SingleLine s) = Just s
    decodeStatus _              = Nothing

instance RedisStatus String where
    decodeStatus = liftM unpack . decodeStatus

instance RedisStatus Status where
    decodeStatus r = do
        s <- decodeStatus r
        return $ case s of
            "OK"     -> Ok
            "PONG"   -> Pong
            "none"   -> None
            "string" -> String
            "hash"   -> Hash
            "list"   -> List
            "set"    -> Set
            "zset"   -> ZSet
            _        -> error $ "unhandled status-code: " ++ s


------------------------------------------------------------------------------
-- RedisBool instances
--
instance RedisBool Bool where
    decodeBool (Integer 1) = Just True
    decodeBool (Integer 0) = Just False
    decodeBool _           = Nothing

instance (Num a) => (RedisBool a) where
    decodeBool (Integer 1) = Just 1
    decodeBool (Integer 0) = Just 0
    decodeBool _           = Nothing


------------------------------------------------------------------------------
-- RedisInt instances
--
instance (Integral a) => RedisInt a where
    decodeInt (Integer i) = Just $ fromIntegral i
    decodeInt _           = Nothing


------------------------------------------------------------------------------
-- RedisKey instances
--
instance RedisKey ByteString where
    decodeKey (Bulk k) = k
    decodeKey _        = Nothing


------------------------------------------------------------------------------
-- RedisValue instances
--
instance RedisString ByteString where
    decodeString (Bulk v) = v
    decodeString _        = Nothing


------------------------------------------------------------------------------
-- RedisList instances
--
instance RedisString a => RedisList [Maybe a] where
    decodeList (MultiBulk (Just rs)) = Just $ map decodeString rs
    decodeList _                     = Nothing


------------------------------------------------------------------------------
-- RedisSet instances
--
instance (Ord a, RedisString a) => RedisSet (Set.Set a) where
    decodeSet = liftM Set.fromList . decodeSet

instance (RedisString a) => RedisSet [a] where
    decodeSet r = catMaybes <$> decodeList r


------------------------------------------------------------------------------
-- RedisHash instances
--
instance (RedisKey k, RedisString v) => RedisHash [(k,v)] where
    decodeHash reply = 
        case reply of
            (MultiBulk (Just rs)) -> pairs rs
            _                     -> Nothing
      where
        pairs []         = Just []
        pairs (_:[])     = Nothing
        pairs (r1:r2:rs) =
            let kv = (,) <$> decodeKey r1 <*> decodeString r2
            in (:) <$> kv <*> pairs rs

instance (Ord k , RedisKey k, RedisString v) => RedisHash (Map.Map k v) where
    decodeHash = liftM Map.fromList . decodeHash

    ------------------------------------------------------------------------------
-- RedisPair instances
--
instance (RedisString a, RedisString b) => RedisPair (a,b) where
    decodePair (MultiBulk (Just [x, y])) =
        (,) <$> decodeString x <*> decodeString y
    decodePair _          = Nothing
