{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds #-}

-- | Provides helpers for compiling constraints
module Language.Granule.Checker.Constraints.Compile (compileTypeConstraintToConstraint) where

import Control.Monad.State.Strict

import Language.Granule.Checker.Monad
import Language.Granule.Checker.Predicates
import Language.Granule.Checker.Kinding (checkKind, synthKind)

import Language.Granule.Syntax.Pretty
import Language.Granule.Syntax.Span
import Language.Granule.Syntax.Type

import Language.Granule.Utils

compileTypeConstraintToConstraint ::
    (?globals :: Globals) => Span -> Type -> Checker Pred
-- compileTypeConstraintToConstraint s (TyApp (TCon (internalName -> "Pushable") t)) = do

compileTypeConstraintToConstraint s (TyInfix op t1 t2) = do
  (k, _, _) <- synthKind s t1
  (result, putChecker) <- peekChecker (checkKind s t2 k)
  case result of
    Right _ -> do
      putChecker
      compileAtType s op t1 t2 k
    Left _ ->
      case k of
        TyVar v -> do
          st <- get
          case lookup v (tyVarContext st) of
            Just (_, ForallQ) | isGenericCoeffectExpression t2 -> compileAtType s op t1 t2 (TyVar v)
            _ -> throw $ UnificationError s t1 t2
        _ -> throw $ UnificationError s t1 t2
compileTypeConstraintToConstraint s t =
  error $ pretty s <> ": I don't know how to compile a constraint `" <> pretty t <> "`"

compileAtType :: (?globals :: Globals) => Span -> TypeOperator -> Type -> Type -> Type -> Checker Pred
compileAtType s op c1 c2 coeffTy = do
  case op of
    TyOpEq -> return $ Con (Eq s c1 c2 coeffTy)
    TyOpNotEq -> return $ Con (Neq s c1 c2 coeffTy)
    TyOpLesserNat -> return $ Con (Lt s c1 c2)
    TyOpGreaterNat -> return $ Con (Gt s c1 c2)
    TyOpLesserEq -> return $ Con (ApproximatedBy s c1 c2 coeffTy)
    TyOpGreaterEq -> return $ Con (ApproximatedBy s c2 c1 coeffTy)
    TyOpLesserEqNat -> return $ Con (LtEq s c1 c2)
    TyOpGreaterEqNat -> return $ Con (GtEq s c1 c2)
    _ -> error $ pretty s <> ": I don't know how to compile binary operator " <> pretty op
