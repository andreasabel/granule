{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds #-}

module Language.Granule.Checker.SubstitutionContexts where

import Language.Granule.Context
import Language.Granule.Syntax.Type
import Language.Granule.Syntax.Pretty
import Language.Granule.Syntax.Helpers

{-| Substitutions map from unification 
    variables to type-level things as defined by substitutors -}
type Substitution = Ctxt Substitutors

{-| Instantiations map from universal variables to type-level things -}
type Instantiation = Ctxt Substitutors

{-| Substitutors are things we want to substitute in... they may be one
     of several things... -}
data Substitutors =
    SubstT  Type
  deriving (Eq, Show)

instance Pretty Substitutors where
  pretty (SubstT t) = pretty t

instance Term Substitution where
  freeVars [] = []
  freeVars ((v, SubstT t):subst) =
    freeVars t ++ freeVars subst

-- | For substitutions which are just renaminings
--   allow the substitution to be inverted
flipSubstitution :: Substitution -> Substitution
flipSubstitution [] = []
flipSubstitution ((var, SubstT (TyVar var')):subst) =
    (var', SubstT (TyVar var)) : flipSubstitution subst

-- Can't flip the substitution so ignore it
flipSubstitution (s:subst) = flipSubstitution subst
