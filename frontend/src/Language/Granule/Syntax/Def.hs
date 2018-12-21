{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE UndecidableInstances #-}

module Language.Granule.Syntax.Def where

import Data.List ((\\), delete)
import GHC.Generics (Generic)

import Language.Granule.Syntax.FirstParameter
import Language.Granule.Syntax.Helpers
import Language.Granule.Syntax.Identifiers
import Language.Granule.Syntax.Span
import Language.Granule.Syntax.Expr
import Language.Granule.Syntax.Type
import Language.Granule.Syntax.Pattern

-- | Top-level ASTs
-- | Comprise a list of data type declarations and a list
-- | of expression definitions
-- | where `v` is the type of values and `a` annotations
data AST v a = AST [DataDecl] [Def v a]

deriving instance (Show (Value v a), Show a) => Show (AST v a)
deriving instance Functor (AST v)

-- | Function definitions
data Def v a = Def Span Id [Equation v a] TypeScheme
  deriving Generic

-- | Single equation of a function
data Equation v a =
    Equation Span a [Pattern a] (Expr v a)
  deriving Generic

deriving instance Functor (Def v)
deriving instance Functor (Equation v)
deriving instance (Show (Value v a), Show a) => Show (Def v a)
deriving instance (Show (Value v a), Show a) => Show (Equation v a)

instance FirstParameter (Def v a) Span
instance FirstParameter (Equation v a) Span

-- | Data type declarations
data DataDecl = DataDecl Span Id [(Id,Kind)] (Maybe Kind) [DataConstr]
  deriving (Generic, Show)

instance FirstParameter DataDecl Span

-- | Data constructors
data DataConstr
  = DataConstrG Span Id TypeScheme -- ^ GADTs
  | DataConstrA Span Id [Type]     -- ^ ADTs
  deriving (Eq, Show, Generic)

instance FirstParameter DataConstr Span

-- | How many data constructors a type has (Nothing -> don't know)
type Cardinality = Maybe Nat

-- | Fresh a whole AST
freshenAST :: AST v a -> AST v a
freshenAST (AST dds defs) = AST dds (map runFreshener defs)

instance Freshenable (Equation v a) where
  freshen (Equation s a ps e) = do
    ps <- mapM freshen ps
    e <- freshen e
    return (Equation s a ps e)

{-| Alpha-convert all bound variables of a definition, modulo the things on the lhs
Eg this:
@
foo : Int -> Int
foo x = (\(x : Int) -> x * 2) x
@
will become
@
foo : Int -> Int
foo x = (\(x0 : Int) -> x0 * 2) x
@

>>> runFreshener $ Def ((1,1),(2,29)) (Id "foo" "foo") [Equation ((2,1),(2,29)) [PVar ((2,5),(2,5)) () (Id "x" "x")] (App ((2,10),(2,29)) () (Val ((2,10),(2,25)) () (Abs () (PVar ((2,12),(2,12)) () (Id "x" "x0")) (Just (TyCon (Id "Int" "Int"))) (Binop ((2,25),(2,25)) () "*" (Val ((2,24),(2,24)) () (Var () (Id "x" "x0"))) (Val ((2,26),(2,26)) () (NumInt 2))))) (Val ((2,29),(2,29)) () (Var () (Id "x" "x"))))] (Forall ((0,0),(0,0)) [] (FunTy (TyCon (Id "Int" "Int")) (TyCon (Id "Int" "Int"))))
Def ((1,1),(2,29)) (Id "foo" "foo") [Equation ((2,1),(2,29)) [PVar ((2,5),(2,5)) () (Id "x" "x_0")] (App ((2,10),(2,29)) () (Val ((2,10),(2,25)) () (Abs () (PVar ((2,12),(2,12)) () (Id "x" "x_1")) (Just (TyCon (Id "Int" "Int"))) (Binop ((2,25),(2,25)) () "*" (Val ((2,24),(2,24)) () (Var () (Id "x" "x_1"))) (Val ((2,26),(2,26)) () (NumInt 2))))) (Val ((2,29),(2,29)) () (Var () (Id "x" "x_0"))))] (Forall ((0,0),(0,0)) [] (FunTy (TyCon (Id "Int" "Int")) (TyCon (Id "Int" "Int"))))
-}
instance Freshenable (Def v a) where
  freshen (Def s var eqs t) = do
    t  <- freshen t
    eqs <- mapM freshen eqs
    return (Def s var eqs t)

instance Term (Equation v a) where
  freeVars (Equation s a binders body) =
      freeVars body \\ concatMap boundVars binders

instance Term (Def v a) where
  freeVars (Def _ name equations _) =
    delete name (concatMap freeVars equations)
