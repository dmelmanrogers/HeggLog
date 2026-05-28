module Haskell2010.Core.Facts
  ( CoreExprFacts (..)
  , CoreKnownValue (..)
  , CoreModuleFacts (..)
  , analyzeCoreExpr
  , analyzeCoreModule
  , coreExprHasNoRuntimeError
  , coreExprIsTotal
  , lookupCoreBindingFacts
  , renderCoreExprFacts
  , renderCoreModuleFacts
  )
where

import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Haskell2010.Core.Pretty (renderCoreType)
import Haskell2010.Core.Syntax
import qualified Haskell2010.Core.Validate as CoreValidate
import Haskell2010.Names (RName, renderRName)
import Haskell2010.Syntax (Literal (..))
import Runtime.Int
  ( HInt
  , addHInt
  , divHInt
  , hintToInteger
  , ltHInt
  , mkHIntLiteral
  , mulHInt
  , remHInt
  , subHInt
  )

data CoreKnownValue
  = CoreKnownLiteral Literal
  | CoreKnownConstructor RName [CoreExpr]
  | CoreKnownLambda CoreBinder CoreExpr
  | CoreKnownTypeLambda [RName] CoreExpr
  deriving stock (Show, Eq, Ord)

data CoreExprFacts = CoreExprFacts
  { coreFactTotal :: Bool
  , coreFactNoError :: Bool
  , coreFactDemandedNames :: Set RName
  , coreFactStrictBinders :: Set RName
  , coreFactDemandedFields :: Map.Map RName (Set Int)
  , coreFactKnownValue :: Maybe CoreKnownValue
  }
  deriving stock (Show, Eq, Ord)

newtype CoreModuleFacts = CoreModuleFacts
  { coreModuleBindingFacts :: Map.Map RName CoreExprFacts
  }
  deriving stock (Show, Eq, Ord)

type FactEnv = Map.Map RName CoreExprFacts

unknownFacts :: CoreExprFacts
unknownFacts =
  CoreExprFacts
    { coreFactTotal = False
    , coreFactNoError = False
    , coreFactDemandedNames = Set.empty
    , coreFactStrictBinders = Set.empty
    , coreFactDemandedFields = Map.empty
    , coreFactKnownValue = Nothing
    }

valueFacts :: CoreKnownValue -> CoreExprFacts
valueFacts known =
  unknownFacts
    { coreFactTotal = True
    , coreFactNoError = True
    , coreFactKnownValue = Just known
    }

coreExprIsTotal :: CoreExprFacts -> Bool
coreExprIsTotal =
  coreFactTotal

coreExprHasNoRuntimeError :: CoreExprFacts -> Bool
coreExprHasNoRuntimeError =
  coreFactNoError

lookupCoreBindingFacts :: RName -> CoreModuleFacts -> Maybe CoreExprFacts
lookupCoreBindingFacts name =
  Map.lookup name . coreModuleBindingFacts

analyzeCoreModule :: CoreModule -> CoreModuleFacts
analyzeCoreModule coreModule =
  CoreModuleFacts (fixFacts initialFacts)
 where
  validationEnv = CoreValidate.moduleValidationEnv coreModule
  pairs = concatMap bindPairs (coreModuleBinds coreModule)
  initialFacts =
    Map.fromList [(coreBinderName binder, unknownFacts) | (binder, _) <- pairs]

  fixFacts facts =
    let next =
          Map.fromList
            [ (coreBinderName binder, analyzeExpr validationEnv facts rhs)
            | (binder, rhs) <- pairs
            ]
     in if next == facts
          then facts
          else fixFacts next

analyzeCoreExpr :: CoreValidate.CoreValidationEnv -> Map.Map RName CoreExprFacts -> CoreExpr -> CoreExprFacts
analyzeCoreExpr =
  analyzeExpr

analyzeExpr :: CoreValidate.CoreValidationEnv -> FactEnv -> CoreExpr -> CoreExprFacts
analyzeExpr validationEnv env = \case
  CVar name _ ->
    demandName name (Map.findWithDefault unknownFacts name env)
  CLit literal _ ->
    valueFacts (CoreKnownLiteral literal)
  CCon name _ ->
    valueFacts (CoreKnownConstructor name [])
  CSpanned _ expression ->
    analyzeExpr validationEnv env expression
  CLam binder body _ ->
    lambdaFacts validationEnv env binder body
  CApp function argument _ ->
    appFacts validationEnv env function argument
  CTypeLam variables body _ ->
    typeLambdaFacts validationEnv env variables body
  CTypeApp function _ _ ->
    typeAppFacts validationEnv env function
  CLet bind body _ ->
    letFacts validationEnv env bind body
  CCase scrutinee binder alternatives _ ->
    caseFacts validationEnv env scrutinee binder alternatives
  CCoerce expression _ ->
    analyzeExpr validationEnv env expression
  CPrimOp op arguments _ ->
    primitiveFacts validationEnv env op arguments
  CForeignCall _ arguments _ ->
    let argumentFacts = map (analyzeExpr validationEnv env) arguments
     in (mergeObservedFacts argumentFacts)
          { coreFactTotal = False
          , coreFactNoError = False
          , coreFactKnownValue = Nothing
          }
  CForeignImportValue {} ->
    unknownFacts

lambdaFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> CoreBinder -> CoreExpr -> CoreExprFacts
lambdaFacts validationEnv env binder body =
  let binderName = coreBinderName binder
      bodyFacts = analyzeExpr validationEnv (Map.insert binderName unknownFacts env) body
      strictBinders =
        if binderName `Set.member` coreFactDemandedNames bodyFacts
          then Set.insert binderName (coreFactStrictBinders bodyFacts)
          else coreFactStrictBinders bodyFacts
   in (valueFacts (CoreKnownLambda binder body))
        { coreFactStrictBinders = strictBinders
        , coreFactDemandedFields = coreFactDemandedFields bodyFacts
        }

typeLambdaFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> [RName] -> CoreExpr -> CoreExprFacts
typeLambdaFacts validationEnv env variables body =
  let bodyFacts = analyzeExpr validationEnv env body
   in (valueFacts (CoreKnownTypeLambda variables body))
        { coreFactStrictBinders = coreFactStrictBinders bodyFacts
        , coreFactDemandedFields = coreFactDemandedFields bodyFacts
        }

appFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> CoreExpr -> CoreExpr -> CoreExprFacts
appFacts validationEnv env function argument =
  case coreFactKnownValue functionFacts of
    Just (CoreKnownConstructor constructorName fields) ->
      constructorApplicationFacts validationEnv constructorName fields argument functionFacts
    Just (CoreKnownLambda binder body) ->
      lambdaApplicationFacts validationEnv env functionFacts binder body argument
    _ ->
      functionFacts
        { coreFactTotal = False
        , coreFactNoError = False
        , coreFactKnownValue = Nothing
        }
 where
  functionFacts =
    analyzeExpr validationEnv env function

typeAppFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> CoreExpr -> CoreExprFacts
typeAppFacts validationEnv env function =
  case coreFactKnownValue functionFacts of
    Just (CoreKnownTypeLambda _ body) ->
      combineSequential functionFacts (analyzeExpr validationEnv env body)
    Just CoreKnownConstructor {} ->
      functionFacts
    _ ->
      functionFacts
        { coreFactTotal = False
        , coreFactNoError = False
        , coreFactKnownValue = Nothing
        }
 where
  functionFacts =
    analyzeExpr validationEnv env function

constructorApplicationFacts ::
  CoreValidate.CoreValidationEnv ->
  RName ->
  [CoreExpr] ->
  CoreExpr ->
  CoreExprFacts ->
  CoreExprFacts
constructorApplicationFacts validationEnv constructorName fields argument functionFacts =
  case Map.lookup constructorName (CoreValidate.coreConstructorTypes validationEnv) of
    Just info
      | length nextFields <= length (constructorFields info) ->
          functionFacts
            { coreFactKnownValue = Just (CoreKnownConstructor constructorName nextFields)
            }
    _ ->
      functionFacts
        { coreFactTotal = False
        , coreFactNoError = False
        , coreFactKnownValue = Nothing
        }
 where
  nextFields =
    fields <> [argument]

lambdaApplicationFacts ::
  CoreValidate.CoreValidationEnv ->
  FactEnv ->
  CoreExprFacts ->
  CoreBinder ->
  CoreExpr ->
  CoreExpr ->
  CoreExprFacts
lambdaApplicationFacts validationEnv env functionFacts binder body argument =
  let argumentFacts = analyzeExpr validationEnv env argument
      binderName = coreBinderName binder
      bodyFacts = analyzeExpr validationEnv (Map.insert binderName argumentFacts env) body
      strictBinders =
        if binderName `Set.member` coreFactDemandedNames bodyFacts
          then Set.insert binderName (coreFactStrictBinders bodyFacts)
          else coreFactStrictBinders bodyFacts
   in (combineSequential functionFacts (hideDemandedName binderName bodyFacts))
        { coreFactStrictBinders = Set.union strictBinders (coreFactStrictBinders functionFacts)
        }

letFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> CoreBind -> CoreExpr -> CoreExprFacts
letFacts validationEnv env bind body =
  case bind of
    CoreNonRec binder rhs ->
      let rhsFacts = analyzeExpr validationEnv env rhs
          binderName = coreBinderName binder
          bodyFacts = analyzeExpr validationEnv (Map.insert binderName rhsFacts env) body
       in hideDemandedName binderName bodyFacts
    CoreRec pairs ->
      let binderNames = map (coreBinderName . fst) pairs
          recEnv = Map.union (Map.fromList [(name, unknownFacts) | name <- binderNames]) env
          bodyFacts = analyzeExpr validationEnv recEnv body
       in hideDemandedNames binderNames bodyFacts

caseFacts ::
  CoreValidate.CoreValidationEnv ->
  FactEnv ->
  CoreExpr ->
  CoreBinder ->
  [CoreAlt] ->
  CoreExprFacts
caseFacts validationEnv env scrutinee binder alternatives =
  case selectKnownAlternative validationEnv env scrutineeFacts binder alternatives of
    Just selectedFacts ->
      combineCaseScrutinee scrutineeFacts selectedFacts
    Nothing ->
      let alternativeFacts =
            map (analyzeAlternative validationEnv env binder) alternatives
          branchDemand =
            intersectDemandedNames (map coreFactDemandedNames alternativeFacts)
          branchStrict =
            Set.unions (map coreFactStrictBinders alternativeFacts)
          branchFields =
            Map.unionsWith Set.union (map coreFactDemandedFields alternativeFacts)
          branchesTotal = all coreFactTotal alternativeFacts
          branchesNoError = all coreFactNoError alternativeFacts
          exhaustive = caseIsExhaustive validationEnv (exprType scrutinee) alternatives
       in CoreExprFacts
            { coreFactTotal = coreFactTotal scrutineeFacts && exhaustive && branchesTotal && branchesNoError
            , coreFactNoError = coreFactNoError scrutineeFacts && exhaustive && branchesNoError
            , coreFactDemandedNames = Set.union (coreFactDemandedNames scrutineeFacts) branchDemand
            , coreFactStrictBinders = Set.union (coreFactStrictBinders scrutineeFacts) branchStrict
            , coreFactDemandedFields = Map.unionWith Set.union (coreFactDemandedFields scrutineeFacts) branchFields
            , coreFactKnownValue = Nothing
            }
 where
  scrutineeFacts =
    analyzeExpr validationEnv env scrutinee

selectKnownAlternative ::
  CoreValidate.CoreValidationEnv ->
  FactEnv ->
  CoreExprFacts ->
  CoreBinder ->
  [CoreAlt] ->
  Maybe CoreExprFacts
selectKnownAlternative validationEnv env scrutineeFacts binder alternatives =
  case coreFactKnownValue scrutineeFacts of
    Just (CoreKnownLiteral literal) ->
      selectLiteral literal
    Just (CoreKnownConstructor constructorName fields) ->
      selectConstructor constructorName fields
    _ ->
      Nothing
 where
  selectLiteral literal =
    case [body | CoreAlt (LiteralAlt altLiteral) [] body <- alternatives, altLiteral == literal] of
      [body] ->
        Just (knownBodyFacts Map.empty body)
      [] ->
        case [body | CoreAlt DefaultAlt [] body <- alternatives] of
          [body] -> Just (knownBodyFacts Map.empty body)
          _ -> Nothing
      _ ->
        Nothing

  selectConstructor constructorName fields =
    case
      [ (fieldBinders, body)
      | CoreAlt (ConstructorAlt altConstructorName) fieldBinders body <- alternatives
      , altConstructorName == constructorName
      ]
    of
      [(fieldBinders, body)]
        | length fieldBinders == length fields ->
            Just (knownBodyFacts (fieldEnv fieldBinders fields) body)
      [] ->
        case [body | CoreAlt DefaultAlt [] body <- alternatives] of
          [body] -> Just (knownBodyFacts Map.empty body)
          _ -> Nothing
      _ ->
        Nothing
   where
    fieldEnv fieldBinders constructorFields =
      Map.fromList
        [ (coreBinderName fieldBinder, analyzeExpr validationEnv env fieldExpr)
        | (fieldBinder, fieldExpr) <- zip fieldBinders constructorFields
        ]

  knownBodyFacts selectedEnv body =
    let binderName = coreBinderName binder
        env' = Map.insert binderName scrutineeFacts (Map.union selectedEnv env)
        bodyFacts = analyzeExpr validationEnv env' body
        localNames = binderName : Map.keys selectedEnv
        constructorDemand =
          case coreFactKnownValue scrutineeFacts of
            Just (CoreKnownConstructor constructorName _) ->
              demandedFieldMap constructorName (Map.keys selectedEnv) bodyFacts
            _ ->
              Map.empty
     in (hideDemandedNames localNames bodyFacts)
          { coreFactDemandedFields =
              Map.unionWith Set.union constructorDemand (coreFactDemandedFields bodyFacts)
          }

analyzeAlternative ::
  CoreValidate.CoreValidationEnv ->
  FactEnv ->
  CoreBinder ->
  CoreAlt ->
  CoreExprFacts
analyzeAlternative validationEnv env binder (CoreAlt altCon binders body) =
  let localNames = coreBinderName binder : map coreBinderName binders
      altEnv =
        Map.union
          (Map.fromList [(name, unknownFacts) | name <- localNames])
          env
      bodyFacts = analyzeExpr validationEnv altEnv body
      fieldDemand =
        case altCon of
          ConstructorAlt constructorName ->
            demandedFieldMap constructorName (map coreBinderName binders) bodyFacts
          _ ->
            Map.empty
   in (hideDemandedNames localNames bodyFacts)
        { coreFactDemandedFields =
            Map.unionWith Set.union fieldDemand (coreFactDemandedFields bodyFacts)
        }

demandedFieldMap :: RName -> [RName] -> CoreExprFacts -> Map.Map RName (Set Int)
demandedFieldMap constructorName fieldNames facts =
  case demandedIndices of
    [] -> Map.empty
    _ -> Map.singleton constructorName (Set.fromList demandedIndices)
 where
  demanded = coreFactDemandedNames facts
  demandedIndices =
    [ index
    | (index, name) <- zip [0 ..] fieldNames
    , name `Set.member` demanded
    ]

combineCaseScrutinee :: CoreExprFacts -> CoreExprFacts -> CoreExprFacts
combineCaseScrutinee scrutineeFacts selectedFacts =
  CoreExprFacts
    { coreFactTotal = coreFactTotal scrutineeFacts && coreFactTotal selectedFacts && coreFactNoError selectedFacts
    , coreFactNoError = coreFactNoError scrutineeFacts && coreFactNoError selectedFacts
    , coreFactDemandedNames = Set.union (coreFactDemandedNames scrutineeFacts) (coreFactDemandedNames selectedFacts)
    , coreFactStrictBinders = Set.union (coreFactStrictBinders scrutineeFacts) (coreFactStrictBinders selectedFacts)
    , coreFactDemandedFields = Map.unionWith Set.union (coreFactDemandedFields scrutineeFacts) (coreFactDemandedFields selectedFacts)
    , coreFactKnownValue = coreFactKnownValue selectedFacts
    }

caseIsExhaustive :: CoreValidate.CoreValidationEnv -> CoreType -> [CoreAlt] -> Bool
caseIsExhaustive validationEnv scrutineeTy alternatives
  | any isDefault alternatives = True
  | scrutineeTy == boolTy =
      Set.fromList boolConstructors `Set.isSubsetOf` constructorAlternatives
  | not (null constructorsForType) =
      Set.fromList constructorsForType `Set.isSubsetOf` constructorAlternatives
  | otherwise = False
 where
  isDefault = \case
    CoreAlt DefaultAlt _ _ -> True
    _ -> False

  constructorAlternatives =
    Set.fromList
      [ name
      | CoreAlt (ConstructorAlt name) _ _ <- alternatives
      ]

  boolConstructors =
    [trueDataConName, falseDataConName]

  constructorsForType =
    [ name
    | (name, info) <- Map.toList (CoreValidate.coreConstructorTypes validationEnv)
    , constructorResult info == scrutineeTy
    ]

primitiveFacts :: CoreValidate.CoreValidationEnv -> FactEnv -> CorePrimOp -> [CoreExpr] -> CoreExprFacts
primitiveFacts validationEnv env op arguments =
  case specialPrimitiveDemand validationEnv env op arguments of
    Just facts ->
      facts
    Nothing ->
      let argumentFacts = map (analyzeExpr validationEnv env) arguments
          observed = mergeObservedFacts argumentFacts
          knownResult = traverse coreFactKnownValue argumentFacts >>= evalKnownPrimitive op
          opNoError = maybe (primitiveNoErrorFromFacts op arguments argumentFacts) (const True) knownResult
          noError = all coreFactNoError argumentFacts && opNoError
       in observed
            { coreFactTotal = all coreFactTotal argumentFacts && noError
            , coreFactNoError = noError
            , coreFactKnownValue = knownResult
            }

specialPrimitiveDemand ::
  CoreValidate.CoreValidationEnv ->
  FactEnv ->
  CorePrimOp ->
  [CoreExpr] ->
  Maybe CoreExprFacts
specialPrimitiveDemand validationEnv env op arguments =
  case (op, arguments) of
    (PrimIOThen, firstExpr : _) ->
      Just (ioBoundaryFacts [analyzeExpr validationEnv env firstExpr])
    (PrimIOBind, firstExpr : _) ->
      Just (ioBoundaryFacts [analyzeExpr validationEnv env firstExpr])
    (PrimIOCatch, actionExpr : _) ->
      Just (ioBoundaryFacts [analyzeExpr validationEnv env actionExpr])
    (PrimIOTry, [actionExpr]) ->
      Just (ioBoundaryFacts [analyzeExpr validationEnv env actionExpr])
    (PrimIOFix, [functionExpr]) ->
      Just (ioBoundaryFacts [analyzeExpr validationEnv env functionExpr])
    _ ->
      Nothing

ioBoundaryFacts :: [CoreExprFacts] -> CoreExprFacts
ioBoundaryFacts evaluatedFacts =
  (mergeObservedFacts evaluatedFacts)
    { coreFactTotal = False
    , coreFactNoError = False
    , coreFactKnownValue = Nothing
    }

primitiveNoErrorFromFacts :: CorePrimOp -> [CoreExpr] -> [CoreExprFacts] -> Bool
primitiveNoErrorFromFacts op arguments argumentFacts =
  case op of
    PrimAdd -> checkedKnownIntBinary addHInt argumentFacts || hasKnownInt 0 argumentFacts
    PrimSub -> checkedKnownIntBinary subHInt argumentFacts || rhsKnownInt 0 argumentFacts
    PrimMul ->
      checkedKnownIntBinary mulHInt argumentFacts
        || hasKnownInt 0 argumentFacts
        || hasKnownInt 1 argumentFacts
    PrimDiv ->
      denominatorSafeForDivision argumentFacts
    PrimRem ->
      denominatorSafeForDivision argumentFacts
    PrimEq -> primitiveEqNoError arguments
    PrimLt -> True
    PrimNegate -> checkedKnownIntUnary (\value -> subHInt zeroHInt value) argumentFacts
    PrimBitAnd -> True
    PrimBitOr -> True
    PrimBitXor -> True
    PrimBitComplement -> True
    PrimShift -> True
    PrimShiftL -> nonNegativeKnownAmount argumentFacts
    PrimShiftR -> nonNegativeKnownAmount argumentFacts
    PrimRotate -> True
    PrimRotateL -> True
    PrimRotateR -> nonNegativeKnownAmount argumentFacts
    PrimBit -> nonNegativeKnownSingle argumentFacts
    PrimTestBit -> nonNegativeKnownAmount argumentFacts
    PrimIntegerAdd -> True
    PrimIntegerSub -> True
    PrimIntegerMul -> True
    PrimIntegerQuot -> integerDenominatorNonZero argumentFacts
    PrimIntegerRem -> integerDenominatorNonZero argumentFacts
    PrimIntegerEq -> True
    PrimIntegerLt -> True
    PrimIntegerNegate -> True
    PrimIntegerAbs -> True
    PrimIntegerSignum -> True
    PrimIntegerToInt -> knownIntegerFitsHInt argumentFacts
    PrimIntToInteger -> True
    PrimIntegerToFloat {} -> True
    PrimShowInteger -> True
    PrimCharToInt -> True
    PrimIntToChar -> knownIntIsChar argumentFacts
    PrimShowInt -> True
    PrimShowBool -> True
    PrimFloat _ floatingOp -> floatingPrimitiveNoError floatingOp
    PrimFloatInt _ floatingOp -> floatingIntPrimitiveNoError floatingOp
    PrimFixedIntegral _ fixedOp -> fixedPrimitiveNoError fixedOp argumentFacts
    _ -> False

evalKnownPrimitive :: CorePrimOp -> [CoreKnownValue] -> Maybe CoreKnownValue
evalKnownPrimitive op values =
  case (op, values) of
    (PrimAdd, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) ->
      knownCheckedInt $ do
        lhsInt <- mkHIntLiteral lhs
        rhsInt <- mkHIntLiteral rhs
        addHInt lhsInt rhsInt
    (PrimSub, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) ->
      knownCheckedInt $ do
        lhsInt <- mkHIntLiteral lhs
        rhsInt <- mkHIntLiteral rhs
        subHInt lhsInt rhsInt
    (PrimMul, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) ->
      knownCheckedInt $ do
        lhsInt <- mkHIntLiteral lhs
        rhsInt <- mkHIntLiteral rhs
        mulHInt lhsInt rhsInt
    (PrimDiv, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) ->
      knownCheckedDivRemInt divHInt lhs rhs
    (PrimRem, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) ->
      knownCheckedDivRemInt remHInt lhs rhs
    (PrimEq, [lhs, rhs]) ->
      evalKnownEq lhs rhs
    (PrimLt, [CoreKnownLiteral (LInt lhs), CoreKnownLiteral (LInt rhs)]) -> do
      lhsInt <- either (const Nothing) Just (mkHIntLiteral lhs)
      rhsInt <- either (const Nothing) Just (mkHIntLiteral rhs)
      CoreKnownConstructor <$> knownBoolConstructor (ltHInt lhsInt rhsInt) <*> pure []
    (PrimIntegerAdd, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      Just (CoreKnownLiteral (LInteger (lhs + rhs)))
    (PrimIntegerSub, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      Just (CoreKnownLiteral (LInteger (lhs - rhs)))
    (PrimIntegerMul, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      Just (CoreKnownLiteral (LInteger (lhs * rhs)))
    (PrimIntegerQuot, [CoreKnownLiteral (LInteger _), CoreKnownLiteral (LInteger 0)]) ->
      Nothing
    (PrimIntegerQuot, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      Just (CoreKnownLiteral (LInteger (lhs `quot` rhs)))
    (PrimIntegerRem, [CoreKnownLiteral (LInteger _), CoreKnownLiteral (LInteger 0)]) ->
      Nothing
    (PrimIntegerRem, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      Just (CoreKnownLiteral (LInteger (lhs `rem` rhs)))
    (PrimIntegerEq, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      CoreKnownConstructor <$> knownBoolConstructor (lhs == rhs) <*> pure []
    (PrimIntegerLt, [CoreKnownLiteral (LInteger lhs), CoreKnownLiteral (LInteger rhs)]) ->
      CoreKnownConstructor <$> knownBoolConstructor (lhs < rhs) <*> pure []
    (PrimIntegerNegate, [CoreKnownLiteral (LInteger value)]) ->
      Just (CoreKnownLiteral (LInteger (negate value)))
    (PrimIntegerAbs, [CoreKnownLiteral (LInteger value)]) ->
      Just (CoreKnownLiteral (LInteger (abs value)))
    (PrimIntegerSignum, [CoreKnownLiteral (LInteger value)]) ->
      Just (CoreKnownLiteral (LInteger (signum value)))
    (PrimIntegerToInt, [CoreKnownLiteral (LInteger value)]) ->
      knownCheckedInt (mkHIntLiteral value)
    (PrimIntToInteger, [CoreKnownLiteral (LInt value)]) ->
      Just (CoreKnownLiteral (LInteger value))
    (PrimCharToInt, [CoreKnownLiteral (LChar value)]) ->
      Just (CoreKnownLiteral (LInt (toInteger (fromEnum value))))
    _ ->
      Nothing

knownCheckedInt :: Either a HInt -> Maybe CoreKnownValue
knownCheckedInt action =
  case action of
    Right value -> Just (CoreKnownLiteral (LInt (hintToInteger value)))
    Left _ -> Nothing

knownCheckedDivRemInt :: (HInt -> HInt -> Either a HInt) -> Integer -> Integer -> Maybe CoreKnownValue
knownCheckedDivRemInt operation lhs rhs
  | rhs == 0 = Nothing
  | otherwise =
      case (mkHIntLiteral lhs, mkHIntLiteral rhs) of
        (Right lhsInt, Right rhsInt) ->
          knownCheckedInt (operation lhsInt rhsInt)
        _ ->
          Nothing

knownBoolConstructor :: Bool -> Maybe RName
knownBoolConstructor True =
  Just trueDataConName
knownBoolConstructor False =
  Just falseDataConName

evalKnownEq :: CoreKnownValue -> CoreKnownValue -> Maybe CoreKnownValue
evalKnownEq lhs rhs =
  CoreKnownConstructor <$> (knownBoolConstructor =<< knownEqResult lhs rhs) <*> pure []

knownEqResult :: CoreKnownValue -> CoreKnownValue -> Maybe Bool
knownEqResult lhs rhs =
  case (lhs, rhs) of
    (CoreKnownLiteral (LInt lhsValue), CoreKnownLiteral (LInt rhsValue)) ->
      Just (lhsValue == rhsValue)
    (CoreKnownLiteral (LInteger lhsValue), CoreKnownLiteral (LInteger rhsValue)) ->
      Just (lhsValue == rhsValue)
    (CoreKnownLiteral (LFloat lhsValue), CoreKnownLiteral (LFloat rhsValue)) ->
      Just (lhsValue == rhsValue)
    (CoreKnownLiteral (LDouble lhsValue), CoreKnownLiteral (LDouble rhsValue)) ->
      Just (lhsValue == rhsValue)
    (CoreKnownLiteral (LChar lhsValue), CoreKnownLiteral (LChar rhsValue)) ->
      Just (lhsValue == rhsValue)
    (CoreKnownConstructor lhsName [], CoreKnownConstructor rhsName [])
      | lhsName `Set.member` boolConstructorSet
      , rhsName `Set.member` boolConstructorSet ->
          Just (lhsName == rhsName)
    _ ->
      Nothing

boolConstructorSet :: Set RName
boolConstructorSet =
  Set.fromList [trueDataConName, falseDataConName]

primitiveEqNoError :: [CoreExpr] -> Bool
primitiveEqNoError = \case
  [lhs, rhs]
    | exprType lhs == exprType rhs ->
        exprType lhs `Set.member` primitiveEqTypes
  _ ->
    False

primitiveEqTypes :: Set CoreType
primitiveEqTypes =
  Set.fromList [intTy, integerTy, boolTy, charTy, floatTy, doubleTy]

checkedKnownIntBinary :: (HInt -> HInt -> Either b c) -> [CoreExprFacts] -> Bool
checkedKnownIntBinary operation facts =
  case mapM knownInt facts of
    Just [lhs, rhs] ->
      case (mkHIntLiteral lhs, mkHIntLiteral rhs) of
        (Right lhsInt, Right rhsInt) ->
          either (const False) (const True) (operation lhsInt rhsInt)
        _ ->
          False
    _ ->
      False

checkedKnownIntUnary :: (HInt -> Either b c) -> [CoreExprFacts] -> Bool
checkedKnownIntUnary operation facts =
  case mapM knownInt facts of
    Just [value] ->
      case mkHIntLiteral value of
        Right intValue -> either (const False) (const True) (operation intValue)
        Left _ -> False
    _ ->
      False

knownInt :: CoreExprFacts -> Maybe Integer
knownInt facts =
  case coreFactKnownValue facts of
    Just (CoreKnownLiteral (LInt value)) -> Just value
    _ -> Nothing

knownInteger :: CoreExprFacts -> Maybe Integer
knownInteger facts =
  case coreFactKnownValue facts of
    Just (CoreKnownLiteral (LInteger value)) -> Just value
    _ -> Nothing

hasKnownInt :: Integer -> [CoreExprFacts] -> Bool
hasKnownInt expected =
  any ((== Just expected) . knownInt)

rhsKnownInt :: Integer -> [CoreExprFacts] -> Bool
rhsKnownInt expected = \case
  [_, rhs] -> knownInt rhs == Just expected
  _ -> False

denominatorSafeForDivision :: [CoreExprFacts] -> Bool
denominatorSafeForDivision = \case
  [lhs, rhs]
    | Just rhsValue <- knownInt rhs
    , rhsValue == 0 -> False
    | Just rhsValue <- knownInt rhs
    , rhsValue /= 0
    , rhsValue /= (-1) -> True
    | Just lhsValue <- knownInt lhs
    , Just rhsValue <- knownInt rhs
    , rhsValue /= 0 ->
        checkedKnownIntBinary divHInt [literalIntFacts lhsValue, literalIntFacts rhsValue]
  _ -> False

integerDenominatorNonZero :: [CoreExprFacts] -> Bool
integerDenominatorNonZero = \case
  [_, rhs] -> maybe False (/= 0) (knownInteger rhs)
  _ -> False

knownIntegerFitsHInt :: [CoreExprFacts] -> Bool
knownIntegerFitsHInt = \case
  [value] -> maybe False (either (const False) (const True) . mkHIntLiteral) (knownInteger value)
  _ -> False

knownIntIsChar :: [CoreExprFacts] -> Bool
knownIntIsChar = \case
  [value] -> maybe False (\code -> 0 <= code && code <= 0x10FFFF) (knownInt value)
  _ -> False

nonNegativeKnownAmount :: [CoreExprFacts] -> Bool
nonNegativeKnownAmount = \case
  [_, amount] -> maybe False (>= 0) (knownInt amount)
  _ -> False

nonNegativeKnownSingle :: [CoreExprFacts] -> Bool
nonNegativeKnownSingle = \case
  [amount] -> maybe False (>= 0) (knownInt amount)
  _ -> False

floatingPrimitiveNoError :: FloatingPrimOp -> Bool
floatingPrimitiveNoError = \case
  FloatEq -> True
  FloatLt -> True
  FloatShow -> True
  FloatFromInt -> True
  FloatAdd -> True
  FloatSub -> True
  FloatMul -> True
  FloatDiv -> True
  FloatNegate -> True
  FloatAbs -> True
  FloatSignum -> True
  FloatExp -> True
  FloatLog -> True
  FloatSqrt -> True
  FloatSin -> True
  FloatCos -> True
  FloatTan -> True
  FloatAsin -> True
  FloatAcos -> True
  FloatAtan -> True
  FloatSinh -> True
  FloatCosh -> True
  FloatTanh -> True
  FloatAsinh -> True
  FloatAcosh -> True
  FloatAtanh -> True
  FloatPow -> True
  FloatAtan2 -> True

floatingIntPrimitiveNoError :: FloatingIntPrimOp -> Bool
floatingIntPrimitiveNoError = \case
  FloatIsNaN -> True
  FloatIsInfinite -> True
  FloatIsDenormalized -> True
  FloatIsNegativeZero -> True
  FloatTruncate -> False
  FloatRound -> False
  FloatCeiling -> False
  FloatFloor -> False

fixedPrimitiveNoError :: FixedIntegralOp -> [CoreExprFacts] -> Bool
fixedPrimitiveNoError op facts =
  case op of
    FixedQuot -> fixedDenominatorSafe facts
    FixedRem -> fixedDenominatorSafe facts
    FixedBit -> nonNegativeKnownSingle facts
    FixedTestBit -> nonNegativeKnownAmount facts
    FixedShiftL -> nonNegativeKnownAmount facts
    FixedShiftR -> nonNegativeKnownAmount facts
    FixedRotateR -> nonNegativeKnownAmount facts
    FixedFromInteger -> False
    _ -> True

fixedDenominatorSafe :: [CoreExprFacts] -> Bool
fixedDenominatorSafe = \case
  [_, rhs] -> maybe False (/= 0) (knownInt rhs)
  _ -> False

literalIntFacts :: Integer -> CoreExprFacts
literalIntFacts value =
  valueFacts (CoreKnownLiteral (LInt value))

zeroHInt :: HInt
zeroHInt =
  case mkHIntLiteral 0 of
    Right value -> value
    Left _ -> error "internal zero HInt literal is out of range"

demandName :: RName -> CoreExprFacts -> CoreExprFacts
demandName name facts =
  facts {coreFactDemandedNames = Set.insert name (coreFactDemandedNames facts)}

hideDemandedName :: RName -> CoreExprFacts -> CoreExprFacts
hideDemandedName name facts =
  facts {coreFactDemandedNames = Set.delete name (coreFactDemandedNames facts)}

hideDemandedNames :: [RName] -> CoreExprFacts -> CoreExprFacts
hideDemandedNames names facts =
  facts {coreFactDemandedNames = foldr Set.delete (coreFactDemandedNames facts) names}

mergeObservedFacts :: [CoreExprFacts] -> CoreExprFacts
mergeObservedFacts facts =
  unknownFacts
    { coreFactDemandedNames = Set.unions (map coreFactDemandedNames facts)
    , coreFactStrictBinders = Set.unions (map coreFactStrictBinders facts)
    , coreFactDemandedFields = Map.unionsWith Set.union (map coreFactDemandedFields facts)
    }

combineSequential :: CoreExprFacts -> CoreExprFacts -> CoreExprFacts
combineSequential first second =
  CoreExprFacts
    { coreFactTotal = coreFactTotal first && coreFactTotal second
    , coreFactNoError = coreFactNoError first && coreFactNoError second
    , coreFactDemandedNames = Set.union (coreFactDemandedNames first) (coreFactDemandedNames second)
    , coreFactStrictBinders = Set.union (coreFactStrictBinders first) (coreFactStrictBinders second)
    , coreFactDemandedFields = Map.unionWith Set.union (coreFactDemandedFields first) (coreFactDemandedFields second)
    , coreFactKnownValue = coreFactKnownValue second
    }

intersectDemandedNames :: [Set RName] -> Set RName
intersectDemandedNames = \case
  [] -> Set.empty
  first : rest -> foldl Set.intersection first rest

bindPairs :: CoreBind -> [(CoreBinder, CoreExpr)]
bindPairs = \case
  CoreNonRec binder rhs -> [(binder, rhs)]
  CoreRec pairs -> pairs

renderCoreModuleFacts :: CoreModuleFacts -> Text
renderCoreModuleFacts (CoreModuleFacts facts) =
  if Map.null facts
    then "none\n"
    else Text.unlines [renderRName name <> ": " <> renderCoreExprFacts fact | (name, fact) <- Map.toList facts]

renderCoreExprFacts :: CoreExprFacts -> Text
renderCoreExprFacts facts =
  Text.intercalate
    ", "
    [ "total=" <> yesNo (coreFactTotal facts)
    , "no-error=" <> yesNo (coreFactNoError facts)
    , "demands=[" <> renderNames (coreFactDemandedNames facts) <> "]"
    , "strict=[" <> renderNames (coreFactStrictBinders facts) <> "]"
    , "fields=[" <> renderFields (coreFactDemandedFields facts) <> "]"
    , "known=" <> renderKnownValue (coreFactKnownValue facts)
    ]

renderKnownValue :: Maybe CoreKnownValue -> Text
renderKnownValue = \case
  Nothing -> "unknown"
  Just (CoreKnownLiteral literal) -> Text.pack (show literal)
  Just (CoreKnownConstructor name fields) ->
    renderRName name <> "/" <> Text.pack (show (length fields))
  Just (CoreKnownLambda binder _) ->
    "lambda " <> renderRName (coreBinderName binder) <> " :: " <> renderCoreType (coreBinderType binder)
  Just (CoreKnownTypeLambda variables _) ->
    "type-lambda [" <> Text.intercalate ", " (map renderRName variables) <> "]"

renderNames :: Set RName -> Text
renderNames names =
  Text.intercalate ", " (map renderRName (Set.toList names))

renderFields :: Map.Map RName (Set Int) -> Text
renderFields fields =
  Text.intercalate
    ", "
    [ renderRName name <> "{" <> Text.intercalate "," (map (Text.pack . show) (Set.toList indices)) <> "}"
    | (name, indices) <- Map.toList fields
    ]

yesNo :: Bool -> Text
yesNo True = "yes"
yesNo False = "no"
