%
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1994
%
\section[HsExpr]{Abstract Haskell syntax: expressions}

\begin{code}
#include "HsVersions.h"

module HsExpr where

import Ubiq{-uitous-}
import HsLoop -- for paranoia checking

-- friends:
import HsBinds		( HsBinds )
import HsLit		( HsLit )
import HsMatches	( pprMatches, pprMatch, Match )
import HsTypes		( PolyType )

-- others:
import Id		( DictVar(..), GenId, Id(..) )
import Outputable
import PprType		( pprGenType, pprParendGenType, GenType{-instance-} )
import Pretty
import PprStyle		( PprStyle(..) )
import SrcLoc		( SrcLoc )
import Usage		( GenUsage{-instance-} )
import Util		( panic{-ToDo:rm eventually-} )
\end{code}

%************************************************************************
%*									*
\subsection{Expressions proper}
%*									*
%************************************************************************

\begin{code}
data HsExpr tyvar uvar id pat
  = HsVar	id				-- variable
  | HsLit	HsLit				-- literal
  | HsLitOut	HsLit				-- TRANSLATION
		(GenType tyvar uvar)		-- (with its type)

  | HsLam	(Match  tyvar uvar id pat)	-- lambda
  | HsApp	(HsExpr tyvar uvar id pat)	-- application
		(HsExpr tyvar uvar id pat)

  -- Operator applications and sections.
  -- NB Bracketed ops such as (+) come out as Vars.

  | OpApp	(HsExpr tyvar uvar id pat)	-- left operand
		(HsExpr tyvar uvar id pat)	-- operator
		(HsExpr tyvar uvar id pat)	-- right operand

  -- ADR Question? Why is the "op" in a section an expr when it will
  -- have to be of the form (HsVar op) anyway?
  -- WDP Answer: But when the typechecker gets ahold of it, it may
  -- apply the var to a few types; it will then be an expression.

  | SectionL	(HsExpr tyvar uvar id pat)	-- operand
		(HsExpr tyvar uvar id pat)	-- operator
  | SectionR	(HsExpr tyvar uvar id pat)	-- operator
		(HsExpr tyvar uvar id pat)	-- operand
				

  | HsCase	(HsExpr tyvar uvar id pat)
		[Match  tyvar uvar id pat]	-- must have at least one Match
		SrcLoc

  | HsIf	(HsExpr tyvar uvar id pat)	--  predicate
		(HsExpr tyvar uvar id pat)	--  then part
		(HsExpr tyvar uvar id pat)	--  else part
		SrcLoc

  | HsLet	(HsBinds tyvar uvar id pat)	-- let(rec)
		(HsExpr  tyvar uvar id pat)

  | HsDo	[Stmt tyvar uvar id pat]	-- "do":one or more stmts
		SrcLoc

  | HsDoOut	[Stmt tyvar uvar id pat]	-- "do":one or more stmts
		id id				-- Monad and MonadZero dicts
		SrcLoc

  | ListComp	(HsExpr tyvar uvar id pat)	-- list comprehension
		[Qual   tyvar uvar id pat]	-- at least one Qual(ifier)

  | ExplicitList		-- syntactic list
		[HsExpr tyvar uvar id pat]
  | ExplicitListOut		-- TRANSLATION
		(GenType tyvar uvar)	-- Gives type of components of list
		[HsExpr tyvar uvar id pat]

  | ExplicitTuple		-- tuple
		[HsExpr tyvar uvar id pat]
				-- NB: Unit is ExplicitTuple []
				-- for tuples, we can get the types
				-- direct from the components

	-- Record construction
  | RecordCon	(HsExpr tyvar uvar id pat)	-- Always (HsVar id) until type checker,
						-- but the latter adds its type args too
		(HsRecordBinds tyvar uvar id pat)

	-- Record update
  | RecordUpd	(HsExpr tyvar uvar id pat)
		(HsRecordBinds tyvar uvar id pat)

  | ExprWithTySig		-- signature binding
		(HsExpr tyvar uvar id pat)
		(PolyType id)
  | ArithSeqIn			-- arithmetic sequence
		(ArithSeqInfo tyvar uvar id pat)
  | ArithSeqOut
		(HsExpr       tyvar uvar id pat) -- (typechecked, of course)
		(ArithSeqInfo tyvar uvar id pat)

  | CCall	FAST_STRING	-- call into the C world; string is
		[HsExpr tyvar uvar id pat]	-- the C function; exprs are the
				-- arguments to pass.
		Bool		-- True <=> might cause Haskell
				-- garbage-collection (must generate
				-- more paranoid code)
		Bool		-- True <=> it's really a "casm"
				-- NOTE: this CCall is the *boxed*
				-- version; the desugarer will convert
				-- it into the unboxed "ccall#".
		(GenType tyvar uvar)	-- The result type; will be *bottom*
				-- until the typechecker gets ahold of it

  | HsSCC	FAST_STRING	-- "set cost centre" (_scc_) annotation
		(HsExpr tyvar uvar id pat) -- expr whose cost is to be measured
\end{code}

Everything from here on appears only in typechecker output.

\begin{code}
  | TyLam			-- TRANSLATION
		[tyvar]
		(HsExpr tyvar uvar id pat)
  | TyApp			-- TRANSLATION
		(HsExpr  tyvar uvar id pat) -- generated by Spec
		[GenType tyvar uvar]

  -- DictLam and DictApp are "inverses"
  |  DictLam
		[id]
		(HsExpr tyvar uvar id pat)
  |  DictApp
		(HsExpr tyvar uvar id pat)
		[id]

  -- ClassDictLam and Dictionary are "inverses" (see note below)
  |  ClassDictLam
		[id]		-- superclass dicts
		[id]		-- methods
		(HsExpr tyvar uvar id pat)
  |  Dictionary
		[id]		-- superclass dicts
		[id]		-- methods

  |  SingleDict			-- a simple special case of Dictionary
		id		-- local dictionary name

type HsRecordBinds tyvar uvar id pat
  = [(id, HsExpr tyvar uvar id pat, Bool)]
	-- True <=> source code used "punning",
	-- i.e. {op1, op2} rather than {op1=e1, op2=e2}
\end{code}

A @Dictionary@, unless of length 0 or 1, becomes a tuple.  A
@ClassDictLam dictvars methods expr@ is, therefore:
\begin{verbatim}
\ x -> case x of ( dictvars-and-methods-tuple ) -> expr
\end{verbatim}

\begin{code}
instance (NamedThing id, Outputable id, Outputable pat,
	  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar) =>
		Outputable (HsExpr tyvar uvar id pat) where
    ppr = pprExpr
\end{code}

\begin{code}
pprExpr sty (HsVar v)
  = (if (isOpLexeme v) then ppParens else id) (ppr sty v)

pprExpr sty (HsLit    lit)   = ppr sty lit
pprExpr sty (HsLitOut lit _) = ppr sty lit

pprExpr sty (HsLam match)
  = ppCat [ppStr "\\", ppNest 2 (pprMatch sty True match)]

pprExpr sty expr@(HsApp e1 e2)
  = let (fun, args) = collect_args expr [] in
    ppHang (pprParendExpr sty fun) 4 (ppSep (map (pprParendExpr sty) args))
  where
    collect_args (HsApp fun arg) args = collect_args fun (arg:args)
    collect_args fun		 args = (fun, args)

pprExpr sty (OpApp e1 op e2)
  = case op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_e1 = pprParendExpr sty e1
    pp_e2 = pprParendExpr sty e2

    pp_prefixly
      = ppHang (pprParendExpr sty op) 4 (ppSep [pp_e1, pp_e2])

    pp_infixly v
      = ppSep [pp_e1, ppCat [pprOp sty v, pp_e2]]

pprExpr sty (SectionL expr op)
  = case op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_expr = pprParendExpr sty expr

    pp_prefixly = ppHang (ppCat [ppStr "( \\ _x ->", ppr sty op])
		       4 (ppCat [pp_expr, ppStr "_x )"])
    pp_infixly v
      = ppSep [ ppBeside ppLparen pp_expr,
	    	ppBeside (pprOp sty v) ppRparen ]

pprExpr sty (SectionR op expr)
  = case op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_expr = pprParendExpr sty expr

    pp_prefixly = ppHang (ppCat [ppStr "( \\ _x ->", ppr sty op, ppPStr SLIT("_x")])
		       4 (ppBeside pp_expr ppRparen)
    pp_infixly v
      = ppSep [ ppBeside ppLparen (pprOp sty v),
		ppBeside pp_expr  ppRparen ]

pprExpr sty (CCall fun args _ is_asm result_ty)
  = ppHang (if is_asm
	    then ppBesides [ppStr "_casm_ ``", ppPStr fun, ppStr "''"]
	    else ppBeside  (ppPStr SLIT("_ccall_ ")) (ppPStr fun))
	 4 (ppSep (map (pprParendExpr sty) args))

pprExpr sty (HsSCC label expr)
  = ppSep [ ppBeside (ppPStr SLIT("_scc_ ")) (ppBesides [ppChar '"', ppPStr label, ppChar '"']),
	    pprParendExpr sty expr ]

pprExpr sty (HsCase expr matches _)
  = ppSep [ ppSep [ppPStr SLIT("case"), ppNest 4 (pprExpr sty expr), ppPStr SLIT("of")],
	    ppNest 2 (pprMatches sty (True, ppNil) matches) ]

pprExpr sty (ListComp expr quals)
  = ppHang (ppCat [ppLbrack, pprExpr sty expr, ppChar '|'])
	 4 (ppSep [interpp'SP sty quals, ppRbrack])

-- special case: let ... in let ...
pprExpr sty (HsLet binds expr@(HsLet _ _))
  = ppSep [ppHang (ppPStr SLIT("let")) 2 (ppCat [ppr sty binds, ppPStr SLIT("in")]),
	   ppr sty expr]

pprExpr sty (HsLet binds expr)
  = ppSep [ppHang (ppPStr SLIT("let")) 2 (ppr sty binds),
	   ppHang (ppPStr SLIT("in"))  2 (ppr sty expr)]

pprExpr sty (HsDo stmts _)
  = ppCat [ppPStr SLIT("do"), ppAboves (map (ppr sty) stmts)]

pprExpr sty (HsIf e1 e2 e3 _)
  = ppSep [ppCat [ppPStr SLIT("if"), ppNest 2 (pprExpr sty e1), ppPStr SLIT("then")],
	   ppNest 4 (pprExpr sty e2),
	   ppPStr SLIT("else"),
	   ppNest 4 (pprExpr sty e3)]

pprExpr sty (ExplicitList exprs)
  = ppBracket (ppInterleave ppComma (map (pprExpr sty) exprs))
pprExpr sty (ExplicitListOut ty exprs)
  = ppBesides [ ppBracket (ppInterleave ppComma (map (pprExpr sty) exprs)),
		ifnotPprForUser sty (ppBeside ppSP (ppParens (pprGenType sty ty))) ]

pprExpr sty (ExplicitTuple exprs)
  = ppParens (ppInterleave ppComma (map (pprExpr sty) exprs))
pprExpr sty (ExprWithTySig expr sig)
  = ppHang (ppBesides [ppLparen, ppNest 2 (pprExpr sty expr), ppPStr SLIT(" ::")])
	 4 (ppBeside  (ppr sty sig) ppRparen)

pprExpr sty (RecordCon con  rbinds)
  = pp_rbinds sty (ppr sty con) rbinds

pprExpr sty (RecordUpd aexp rbinds)
  = pp_rbinds sty (pprParendExpr sty aexp) rbinds

pprExpr sty (ArithSeqIn info)
  = ppBracket (ppr sty info)
pprExpr sty (ArithSeqOut expr info)
  = case sty of
  	PprForUser ->
    	  ppBracket (ppr sty info)
	_   	   ->
    	  ppBesides [ppLbrack, ppParens (ppr sty expr), ppr sty info, ppRbrack]

pprExpr sty (TyLam tyvars expr)
  = ppHang (ppCat [ppStr "/\\", interppSP sty tyvars, ppStr "->"])
	 4 (pprExpr sty expr)

pprExpr sty (TyApp expr [ty])
  = ppHang (pprExpr sty expr) 4 (pprParendGenType sty ty)

pprExpr sty (TyApp expr tys)
  = ppHang (pprExpr sty expr)
	 4 (ppBracket (interpp'SP sty tys))

pprExpr sty (DictLam dictvars expr)
  = ppHang (ppCat [ppStr "\\{-dict-}", interppSP sty dictvars, ppStr "->"])
	 4 (pprExpr sty expr)

pprExpr sty (DictApp expr [dname])
  = ppHang (pprExpr sty expr) 4 (ppr sty dname)

pprExpr sty (DictApp expr dnames)
  = ppHang (pprExpr sty expr)
	 4 (ppBracket (interpp'SP sty dnames))

pprExpr sty (ClassDictLam dicts methods expr)
  = ppHang (ppCat [ppStr "\\{-classdict-}",
		   ppBracket (interppSP sty dicts),
		   ppBracket (interppSP sty methods),
		   ppStr "->"])
	 4 (pprExpr sty expr)

pprExpr sty (Dictionary dicts methods)
 = ppSep [ppBesides [ppLparen, ppPStr SLIT("{-dict-}")],
	  ppBracket (interpp'SP sty dicts),
	  ppBesides [ppBracket (interpp'SP sty methods), ppRparen]]

pprExpr sty (SingleDict dname)
 = ppCat [ppPStr SLIT("{-singleDict-}"), ppr sty dname]
\end{code}

Parenthesize unless very simple:
\begin{code}
pprParendExpr :: (NamedThing id, Outputable id, Outputable pat,
		  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar)
	      => PprStyle -> HsExpr tyvar uvar id pat -> Pretty

pprParendExpr sty expr
  = let
	pp_as_was = pprExpr sty expr
    in
    case expr of
      HsLit l		    -> ppr sty l
      HsLitOut l _	    -> ppr sty l
      HsVar _		    -> pp_as_was
      ExplicitList _	    -> pp_as_was
      ExplicitListOut _ _   -> pp_as_was
      ExplicitTuple _	    -> pp_as_was
      _			    -> ppParens pp_as_was
\end{code}

%************************************************************************
%*									*
\subsection{Record binds}
%*									*
%************************************************************************

\begin{code}
pp_rbinds :: (NamedThing id, Outputable id, Outputable pat,
		  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar)
	      => PprStyle -> Pretty 
	      -> HsRecordBinds tyvar uvar id pat -> Pretty

pp_rbinds sty thing rbinds
  = ppHang thing 4
	(ppBesides [ppChar '{', ppInterleave ppComma (map (pp_rbind sty) rbinds), ppChar '}'])
  where
    pp_rbind sty (v, _, True{-pun-}) = ppr sty v
    pp_rbind sty (v, e, _) = ppCat [ppr sty v, ppStr "<-", ppr sty e]
\end{code}

%************************************************************************
%*									*
\subsection{Do stmts}
%*									*
%************************************************************************

\begin{code}
data Stmt tyvar uvar id pat
  = BindStmt	pat
		(HsExpr  tyvar uvar id pat)
		SrcLoc
  | ExprStmt	(HsExpr  tyvar uvar id pat)
		SrcLoc
  | LetStmt	(HsBinds tyvar uvar id pat)
\end{code}

\begin{code}
instance (NamedThing id, Outputable id, Outputable pat,
	  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar) =>
		Outputable (Stmt tyvar uvar id pat) where
    ppr sty (BindStmt pat expr _)
     = ppCat [ppr sty pat, ppStr "<-", ppr sty expr]
    ppr sty (LetStmt binds)
     = ppCat [ppPStr SLIT("let"), ppr sty binds]
    ppr sty (ExprStmt expr _)
     = ppr sty expr
\end{code}

%************************************************************************
%*									*
\subsection{Enumerations and list comprehensions}
%*									*
%************************************************************************

\begin{code}
data ArithSeqInfo  tyvar uvar id pat
  = From	    (HsExpr tyvar uvar id pat)
  | FromThen 	    (HsExpr tyvar uvar id pat)
		    (HsExpr tyvar uvar id pat)
  | FromTo	    (HsExpr tyvar uvar id pat)
		    (HsExpr tyvar uvar id pat)
  | FromThenTo	    (HsExpr tyvar uvar id pat)
		    (HsExpr tyvar uvar id pat)
		    (HsExpr tyvar uvar id pat)
\end{code}

\begin{code}
instance (NamedThing id, Outputable id, Outputable pat,
	  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar) =>
		Outputable (ArithSeqInfo tyvar uvar id pat) where
    ppr sty (From e1)		= ppBesides [ppr sty e1, pp_dotdot]
    ppr sty (FromThen e1 e2)	= ppBesides [ppr sty e1, pp'SP, ppr sty e2, pp_dotdot]
    ppr sty (FromTo e1 e3)	= ppBesides [ppr sty e1, pp_dotdot, ppr sty e3]
    ppr sty (FromThenTo e1 e2 e3)
      = ppBesides [ppr sty e1, pp'SP, ppr sty e2, pp_dotdot, ppr sty e3]

pp_dotdot = ppPStr SLIT(" .. ")
\end{code}

``Qualifiers'' in list comprehensions:
\begin{code}
data Qual tyvar uvar id pat
  = GeneratorQual   pat
		    (HsExpr  tyvar uvar id pat)
  | LetQual	    (HsBinds tyvar uvar id pat)
  | FilterQual	    (HsExpr  tyvar uvar id pat)
\end{code}

\begin{code}
instance (NamedThing id, Outputable id, Outputable pat,
	  Eq tyvar, Outputable tyvar, Eq uvar, Outputable uvar) =>
		Outputable (Qual tyvar uvar id pat) where
    ppr sty (GeneratorQual pat expr)
     = ppCat [ppr sty pat, ppStr "<-", ppr sty expr]
    ppr sty (LetQual binds)
     = ppCat [ppPStr SLIT("let"), ppr sty binds]
    ppr sty (FilterQual expr)
     = ppr sty expr
\end{code}
