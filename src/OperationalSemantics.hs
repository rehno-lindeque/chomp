--{-# OPTIONS_GHC -fno-warn-overlapping-patterns #-}

module OperationalSemantics where

{-                               DOCUMENTATION                              -}
{-
    Operational semantics expressed as haskell functions.

    CONVENTIONS:
      Semantics are documented like they would be in a paper, using a style
      similar to natural deduction.

      The assumptions placed before the turnstile |- is exactly the context
      in which a computation takes place.
      Usually this will be written 'ctx |-', but sometimes we will use the
      notation '(cs -> c) |-' similar to (and corresponding, in the code, with)
      haskell's pattern matching '(c:cs)' notation.
      When written in this way, c refers to the head of a chain of arrows and
      may be selected from like a regular symbol e.g. 'c:exp'.

      There is one special consideration however, the context listed before
      the turnstile does not include the expression on the right of the
      turnstile itself! Hence, the implementation must be specifically
      exclude it from checks such as 'c:exp'.

      These functions may be affected
      * conjunctContextContaining
      * conjunctContext
      * conjunctCollection

      For the purposes of documenting the semantics '^' is a special pseudo-
      operator looking up a variable in the context similar to how the
      standard '.' operator works, but recursively in the scope. (Thus the
      documentation for the semantics might have expressions like 'ctx ^ exp'.

      In addition, the following conventions are typically used for variable names:
      * ex            A single expression
      * exs@(e:es)    A list of expressions
      * ctx@(c:cs)    A context
      * r             A result
      * t             A token

    BUGS:
      + (2011-06-28)
        Currently it's not too clear whether the matching code which must evaluate expressions
        in higher up contexts should perform error checking. Theoretically we want to check
        queries even when they do not return a result in order to build code like this
        '{ checkParameters result }:result' where checkParameters does not need to be evaluated
        for the result, but is necessary for proof code. However, exactly how this will work is not
        entirely certain for now - currently assuming that every context will be checked, but
        not checking context variables when doing a lookup in the scope (i.e. conjunctContext)
        in order to avoid double checking things. This is probably not correct though, it is
        more likely that results will have to be memoized to avoid repeating work.

        The main functions affected are
        * conjunctCollection
        * conjunctContext
        * evalWithConjunct
        * uncheckedEval
-}

{-                                 MODULES                                  -}
-- Standard
import Control.Monad (foldM)

-- Chomp
import SyntaxTree

{-                              IMPLEMENTATION                              -}

-- Top level semantics

-- A context is the path (stack of arrow declarations) leading to the current computation
-- Note that the top of the stack is the head of the list
type Context = [[Expression]]

--instance Show Context where
--  show c = ""

-- The result of a computation. Allows eval to return Error
-- type Result = Maybe [Expression]
data Result a = Success [a] | Error
type EvalResult = Result Expression

-- Auxiliary functions

-- Convert an empty list to an "error" result and a non-empty list to "success"
listToResult :: [a] -> Result a
listToResult [] = Error
listToResult l  = Success l

-- Unwrap a result, converting an "error" value into an empty list
resultToList :: Result a -> [a]
resultToList (Success l) = l
resultToList Error       = []

-- Map a evaluation function over a set of expression and the fold the list into a Result
-- This function short-circuits as soon as an error is reached
foldEval :: (Expression -> EvalResult) -> [Expression] -> EvalResult
foldEval f (e:es) =
  case f e of
    (Success exs') -> case foldEval f es of
      (Success exs'') -> Success (exs' ++ exs'')
      Error       -> Error
    Error -> Error

-- Attempt match an expression to the another expression inside the current context
-- Note that this is not just a simple equality test. There is a left-hand side expression and a
-- right-hand side expression and both may be queries themselves. Therefore both need to be
-- evaluated before they can be matched.
-- Furthermore (a -> b -> c) on the LHS will match (a -> b) on the RHS but (a -> b) on the LHS will
-- not match (a -> b -> c) on the RHS.
-- The function returns the result of the match as a new collection.

--matchExpression :: Context -> Expression -> Expression -> [Expression]
--matchExpression ctx  rhs =

-- Match an element inside a collection and return all matching expressions
-- TODO: NOT SURE IF THIS SHOULD RETURN A RESULT OR JUST A LIST OF EXPRESSIONS...
conjunctCollection :: Context -> [Expression] -> Expression -> [Expression]
conjunctCollection ctx []     ex = []
conjunctCollection ctx [e]    ex = evalWithConjunct ctx e ex
conjunctCollection ctx (e:es) ex = (evalWithConjunct ctx e ex) ++ (conjunctCollection ctx es ex)

-- Evaluate the left-hand side of a conjunct in order to match it to the right-hand side
-- TODO: This function almost certainly needs to be tested (possibly using smallcheck to generate
--       various contexts and then specific expression for the LHS and RHS... although it might not
--       be possible to match the expected result in this way, so might have to manually code
--       contexts and expected results)
-- TODO: NOT SURE IF THIS SHOULD RETURN A RESULT OR JUST A LIST OF EXPRESSIONS...
evalWithConjunct :: Context -> Expression -> Expression -> [Expression]
evalWithConjunct ctx _           (Eval (Assert _) [])     = error "IMPOSSIBLE ERROR: Not possible to have two selectors in succession."
evalWithConjunct ctx _           (Eval (Witness _) [])    = error "IMPOSSIBLE ERROR: Not possible to have two selectors in succession."
evalWithConjunct ctx _           (Eval (Assert _) ex1)    = error "IMPOSSIBLE ERROR: Right-hand query should have been evaluated before the left-hand query is evaluated."
evalWithConjunct ctx _           (Eval (Witness _) ex1)   = error "IMPOSSIBLE ERROR: Right-hand query should have been evaluated before the left-hand query is evaluated."
evalWithConjunct ctx ex0         Top                      = uncheckedEval ctx ex0
evalWithConjunct ctx (Symbol t0) ex1@(Symbol t1)          = if t0 == t1 then [ex1] else []
evalWithConjunct ctx (Symbol t0) ex1@(Eval (Declare _) _) = []
evalWithConjunct ctx Top         ex1                      = [ex1]
evalWithConjunct ctx Top         ex1                      = [ex1]

----------------- BUSY HERE: These are the more complicated cases...
evalWithConjunct ctx ex0@(Eval (Declare ex00) ex01) ex1   = error "TODO: ..... NOT SURE YET WHAT TO DO HERE"
--evalWithConjunct ctx ex0@(Eval _ _)                 ex1   = conjunctCollection (TODO: what context should be used here?) $ uncheckedEval ctx ex0 $ ex1


-- Find an expression in the given context and return all matching expressions
-- Note that the expression must not be stated in the same context that we are searching in (or it
-- will simply match itself, causing an infinite loop)
-- TODO: NOT SURE IF THIS SHOULD RETURN A RESULT OR JUST A LIST OF EXPRESSIONS...
conjunctContext :: Context -> Expression -> [Expression]
conjunctContext []         _  = []
conjunctContext [c]        ex = conjunctCollection [] c ex
conjunctContext ctx@(c:cs) ex = if matches /= [] then matches else conjunctContext cs ex
  where
    matches = conjunctCollection ctx c ex   -- TODO: IS THIS THE CORRECT CONTEXT TO PASS THROUGH?
                                            --       POSSIBLY NEED TO LOOK AT THE CODE IN CONJUNCT
                                            --       TO ENSURE CIRCULAR REFERENCES DO NOT TAKE PLACE

-- Find an expression in the same context that it stated
-- TODO: How do we guarantee that the expression is not matched to itself?
--       This function probably needs an index to be passed through with the expression so as to
--       avoid circular matches.
--       However perhaps there is a more clever solution using zippers or something similar that
--       will improve the overall design
conjunctContextContaining :: Context -> Expression -> [Expression]
conjunctContextContaining (c:cs) ex = error "TODO: ..... TOP-LEVEL CONJUNCT. YET TO BE IMPLEMENTED."

-- Evaluates the expression inside the stack of contexts given
eval :: Context -> Expression -> EvalResult

{-
ctx |- exs0 -> exs1
-------------------
ctx |- exs0 -> exs1
-}

eval ctx ex@(Eval (Declare exs0) exs1)
  | True = Success [ex]

{-
  (cs -> c) |- :exs1
  ------------------
       c:exs1
-}

eval ctx ex@(Eval (Assert (Conjunct exs1)) [])
  | True = listToResult $ concat $ map (conjunctContext ctx) exs1

{-
ctx |- exs1:exs2
-----------------
ctx |- .exs1:exs2
-----------------
(ctx `.` exs1):exs2
-}

eval ctx ex@(Eval (Witness (Conjunct exs1)) [])
  | True =  Success $ concat $ map (conjunctContext ctx) exs1

{-
ctx |- exs0 . exs1
------------------
ctx |- ????????

(Eval (Witness (Conjunct exs0) exs1)

ctx |- exs0 \ exs1
------------------
ctx |- ????????

(Eval (Assert  (Complement exs0) exs1)

ctx |- exs0 \\ exs1
------------------
ctx |- ????????

(Eval (Witness (Complement exs0) exs1)

-}


-- Evaluates the expression exactly like eval, but ignoring any errors

--TODO: Just calling eval might not be correct, because it might only return a partial result
--      when it has an error... for now we're just assuming this is the correct implementation for
--      simplicity. Will come back to it later.
uncheckedEval :: Context -> Expression -> [Expression]
uncheckedEval ctx ex = resultToList $ eval ctx ex