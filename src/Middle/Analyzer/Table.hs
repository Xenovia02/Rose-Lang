module Middle.Analyzer.Table (
    -- searchDatatypes, searchTraits, searchGlobals, searchScopeds,
    findDatatype,
    findTrait,
    findGlobal,
    findScoped,

    lookupType,
    lookupTrait,
    lookupGlobal,
    lookupScoped,

    modifyDatatype,
    modifyTrait,

    pushDatatype,
    pushTrait,
    pushUndefTrait,
    pushCtor,
    pushUndefCtor,
    pushMethod,
    pushFunction,
    pushUndefFunc,
    pushFunction',
    pushScoped,
) where

import Prelude hiding (lookup)

import Control.Monad ((<$!>))

import Common.Typing
import Common.Var
import Front.Parser
import Middle.Analyzer.Internal
import Middle.Table


-- Thus is the convention for Var Table lookups:
--   - `search*` always returns a `SymbolData` object.
--       It will insert an "undefined" symbol into the
--       appropriate table if it is not found.
--   - `lookup*` returns a `Maybe SymbolData` object.
--       `Nothing` if not found, and `Just dta` if found.
--   - `find*` will throw an error if it was not found.


-- impossible because it requires a `Kind`, and we cannot
-- get that from just a `Var`
-- searchDatatypes :: Var -> Analyzer Datatype
-- searchDatatypes name = do
--     typs <- tblTypes <$!> getTable
--     case lookup name typs of
--         Nothing -> do
--             let dta = undefined
--             modifyTable (insertType name dta)
--             return dta
--         Just dta -> return $! dta

-- impossible because it requires a `Kind`, and we cannot
-- get that from just a `Var`
-- searchTraits :: Var -> Analyzer Trait
-- searchTraits name = do
--     trts <- tblTraits <$!> getTable
--     case lookup name trts of
--         Nothing -> do
--             let dta = undefined
--             modifyTable (insertTrait name dta)
--             return dta
--         Just dta -> return $! dta

-- impossible because we dont know what type of
-- global it is
-- searchGlobals :: Var -> Analyzer Global
-- searchGlobals name = do
--     glbs <- tblGlobals <$!> getTable
--     case lookup name glbs of
--         Nothing -> do
--             eT <- peekExpType
--             let dta = mkSymbolData name eT Nothing Nothing
--             expType <- peekExpType
--             dta' <- case expType of
--                 NoType -> return dta
--                 typ -> return $! dta
--                     { sdType = typ <::> sdType dta }
--             modifyTable (insertGlobal name dta')
--             return dta
--         Just dta -> return $! dta

-- just no.
-- searchScopeds :: Var -> Analyzer Scoped
-- searchScopeds name = do
--     scps <- tblScopeds <$!> getTable
--     go scps
--     where
--         go [] = searchGlobals name
--         go (scp:scps) = maybe (go scps)
--             return (lookup name scp)

findDatatype :: Var -> Analyzer Datatype
findDatatype name = lookupType name >>= maybe
    (throwUndefined name) return

findTrait :: Var -> Analyzer Trait
findTrait name = lookupTrait name >>= maybe
    (throwUndefined name) return

findGlobal :: Var -> Analyzer Global
findGlobal name = lookupGlobal name >>= maybe
    (throwUndefined name) return

findScoped :: Var -> Analyzer Scoped
findScoped name = lookupScoped name >>= maybe
    (throwUndefined name) return


lookupType :: Var -> Analyzer (Maybe Datatype)
lookupType name = do
    types <- tblTypes <$!> getTable
    return $! lookup name types

lookupTrait :: Var -> Analyzer (Maybe Trait)
lookupTrait name = do
    trts <- tblTraits <$!> getTable
    return $! lookup name trts

lookupGlobal :: Var -> Analyzer (Maybe Global)
lookupGlobal name = do
    glbs <- tblGlobals <$!> getTable
    return $! lookup name glbs

lookupScoped :: Var -> Analyzer (Maybe Scoped)
lookupScoped name = do
    scps <- tblScopeds <$!> getTable
    go scps
    where
        go :: ScopedMaps -> Analyzer (Maybe Scoped)
        go [] = return Nothing
        go (scp:scps) = case lookup name scp of
            Nothing -> go scps
            Just dta -> return (Just dta)


modifyDatatype :: Var -> (Datatype -> Datatype) -> Analyzer ()
modifyDatatype name f = modifyTable_ $ \tbl ->
    tbl { tblTypes = adjust f name (tblTypes tbl) }

modifyTrait :: Var -> (Trait -> Trait) -> Analyzer ()
modifyTrait name f = modifyTable_ $ \tbl ->
    tbl { tblTraits = adjust f name (tblTraits tbl) }


pushDatatype :: Var -> Visib -> Analyzer Datatype
pushDatatype name vis = do
    let dta = Datatype vis [] (varPos name)
    modifyTable_ (insertType name dta)
    return dta

pushTrait :: Var -> Visib -> Analyzer Trait
pushTrait name vis = do
    let dta = Trait vis [] [] (varPos name)
    modifyTable_ (insertTrait name dta)
    return dta

pushUndefTrait :: Var -> Analyzer Trait
pushUndefTrait name = do
    let dta = Trait Export [] [] (varPos name)
    modifyTable_ (insertTrait name dta)
    return dta

pushCtor :: Var -> Visib -> Var -> Analyzer Global
pushCtor name vis parent = do
    let dta = Constructor vis parent (varPos name)
    modifyTable_ (insertGlobal name dta)
    modifyDatatype parent (\d -> d { dtCtors = (name:dtCtors d) })
    return dta

pushUndefCtor :: Var -> Analyzer Global
pushUndefCtor name = do
    -- !!!TODO: undefined
    let dta = Constructor Export (prim "UNDEFINED") (varPos name)
    modifyTable_ (insertGlobal name dta)
    return dta

pushFunction :: Var -> Visib -> Analyzer Global
pushFunction name vis = do
    let dta = Function vis Nothing (varPos name)
    modifyTable_ (insertGlobal name dta)
    return dta

pushUndefFunc :: Var -> Analyzer Global
pushUndefFunc name = do
    -- TODO: get current/expoected purity
    -- instead of `Nothing` or `Unsafe`
    let dta = Function Export Nothing (varPos name)
    modifyTable_ (insertGlobal name dta)
    return dta

pushFunction' :: Var -> Visib -> Purity -> Analyzer Global
pushFunction' name vis pur = do
    let dta = Function vis (Just pur) (varPos name)
    modifyTable_ (insertGlobal name dta)
    return dta

pushMethod :: Var -> Visib -> Purity -> Var -> Analyzer Global
pushMethod name vis pur parent = do
    let dta = Method vis (Just pur) parent (varPos name)
    modifyTable_ (insertGlobal name dta)
    modifyTrait parent (\t -> t { trtMeths = (name:trtMeths t) })
    return dta

pushScoped :: Var -> Mutab -> Analyzer Scoped
pushScoped name mut = do
    let dta = Scp mut (varPos name)
    modifyTable_ (insertScoped name dta)
    return dta
