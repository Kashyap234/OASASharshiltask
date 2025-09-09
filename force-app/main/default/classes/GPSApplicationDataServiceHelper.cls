public with sharing class GPSApplicationDataServiceHelper {
    
    public static void populateAbatementStrategyFields(Abatement_Strategy__c abatementStrategy, Map<String, Object> partner) {
        if (partner.containsKey('Partner_Name__c') && partner.get('Partner_Name__c') != null && String.valueOf(partner.get('Partner_Name__c')).trim() != '') {
            abatementStrategy.Partner_Name__c = (String) partner.get('Partner_Name__c');
        }
        if (partner.containsKey('Describe_Current_Budget_and_Funding_Sour__c') && partner.get('Describe_Current_Budget_and_Funding_Sour__c') != null && String.valueOf(partner.get('Describe_Current_Budget_and_Funding_Sour__c')).trim() != '') {
            abatementStrategy.Describe_Current_Budget_and_Funding_Sour__c = (String) partner.get('Describe_Current_Budget_and_Funding_Sour__c');
        }
        if (partner.containsKey('Geographic_Area_Population_Poverty__c') && partner.get('Geographic_Area_Population_Poverty__c') != null && String.valueOf(partner.get('Geographic_Area_Population_Poverty__c')).trim() != '') {
            abatementStrategy.Geographic_Area_Population_Poverty__c = (String) partner.get('Geographic_Area_Population_Poverty__c');
        }
        if (partner.containsKey('Outline_Existing_Efforts_and_New_Expansi__c') && partner.get('Outline_Existing_Efforts_and_New_Expansi__c') != null && String.valueOf(partner.get('Outline_Existing_Efforts_and_New_Expansi__c')).trim() != '') {
            abatementStrategy.Outline_Existing_Efforts_and_New_Expansi__c = (String) partner.get('Outline_Existing_Efforts_and_New_Expansi__c');
        }

        if (partner.containsKey('strategiesData') && partner.get('strategiesData') != null) {
            Object strategiesDataObj = partner.get('strategiesData');
            String strategiesDataJson = JSON.serialize(strategiesDataObj);
            Map<String, Object> strategiesData = (Map<String, Object>) JSON.deserializeUntyped(strategiesDataJson);

            populateStrategySelections(abatementStrategy, strategiesData);
        }
    }

    public static void populateStrategySelections(Abatement_Strategy__c abatementStrategy, Map<String, Object> strategiesData) {
        if (strategiesData.containsKey('selectedCoreStrategies') && strategiesData.get('selectedCoreStrategies') != null) {
            List<Object> coreStrategies = (List<Object>) strategiesData.get('selectedCoreStrategies');
            List<String> strategyValues = new List<String>();
            for (Object strategy : coreStrategies) {
                if (strategy != null && String.valueOf(strategy).trim() != '') {
                    strategyValues.add((String) strategy);
                }
            }

            if (!strategyValues.isEmpty()) {
                abatementStrategy.Core_Strategies__c = String.join(strategyValues, ';');
            } else {
                abatementStrategy.Core_Strategies__c = null;
            }
        }

        if (strategiesData.containsKey('selectedCoreAbatements') && strategiesData.get('selectedCoreAbatements') != null) {
            List<Object> abatementStrategiesList = (List<Object>) strategiesData.get('selectedCoreAbatements');
            List<String> abatementValues = new List<String>();
            for (Object strategy : abatementStrategiesList) {
                if (strategy != null && String.valueOf(strategy).trim() != '') {
                    abatementValues.add((String) strategy);
                }
            }

            if (!abatementValues.isEmpty()) {
                abatementStrategy.Core_Abatement_Strategies__c = String.join(abatementValues, ';');
            } else {
                abatementStrategy.Core_Abatement_Strategies__c = null;
            }
        }

        if (strategiesData.containsKey('selectedApprovedUses') && strategiesData.get('selectedApprovedUses') != null) {
            List<Object> approvedUses = (List<Object>) strategiesData.get('selectedApprovedUses');
            List<String> approvedUseValues = new List<String>();
            for (Object use : approvedUses) {
                if (use != null && String.valueOf(use).trim() != '') {
                    approvedUseValues.add((String) use);
                }
            }

            if (!approvedUseValues.isEmpty()) {
                abatementStrategy.Approved_Uses__c = String.join(approvedUseValues, ';');
            } else {
                abatementStrategy.Approved_Uses__c = null;
            }
        }

        if (strategiesData.containsKey('selectedApprovedAbatements') && strategiesData.get('selectedApprovedAbatements') != null) {
            List<Object> approvedAbatements = (List<Object>) strategiesData.get('selectedApprovedAbatements');
            List<String> approvedAbatementValues = new List<String>();
            for (Object abatement : approvedAbatements) {
                if (abatement != null && String.valueOf(abatement).trim() != '') {
                    approvedAbatementValues.add((String) abatement);
                }
            }

            if (!approvedAbatementValues.isEmpty()) {
                if (approvedAbatementValues.size() < 99) {
                    abatementStrategy.Approved_Abatement_Strategies__c = String.join(approvedAbatementValues, ';');
                    abatementStrategy.Overflow_Approved_Value__c = null;
                    abatementStrategy.Overflow_Approved__c = false;
                } else {
                    List<String> first99Values = new List<String>();
                    for (Integer i = 0; i < 99 && i < approvedAbatementValues.size(); i++) {
                        first99Values.add(approvedAbatementValues[i]);
                    }
                    abatementStrategy.Approved_Abatement_Strategies__c = String.join(first99Values, ';');
                    
                    List<String> remainingValues = new List<String>();
                    for (Integer i = 99; i < approvedAbatementValues.size(); i++) {
                        remainingValues.add(approvedAbatementValues[i]);
                    }
                    abatementStrategy.Overflow_Approved_Value__c = String.join(remainingValues, ';');
                    abatementStrategy.Overflow_Approved__c = true;
                }
            } else {
                abatementStrategy.Approved_Abatement_Strategies__c = null;
                abatementStrategy.Overflow_Approved_Value__c = null;
                abatementStrategy.Overflow_Approved__c = false;
            }
        }
    }

    public static void deleteExistingPartnersData(Id applicationId) {
        List<Abatement_Strategy__c> strategies = [SELECT Id FROM Abatement_Strategy__c WHERE Funding_Application__c = :applicationId];
        if (!strategies.isEmpty()) {
            deleteAbatementStrategiesAndChildren(strategies);
        }
    }

    public static void deleteSpecificAbatementStrategies(List<Id> strategyIds) {
        if (strategyIds.isEmpty()) return;
        
        List<Abatement_Strategy__c> strategiesToDelete = [SELECT Id FROM Abatement_Strategy__c WHERE Id IN :strategyIds];
        if (!strategiesToDelete.isEmpty()) {
            deleteAbatementStrategiesAndChildren(strategiesToDelete);
        }
    }

    public static void deleteAbatementStrategiesAndChildren(List<Abatement_Strategy__c> strategies) {
        List<Id> strategyIds = new List<Id>();
        for (Abatement_Strategy__c strategy : strategies) {
            strategyIds.add(strategy.Id);
        }

        // Delete Strategy Resources
        List<Strategy_Resources__c> resources = [SELECT Id FROM Strategy_Resources__c WHERE Abatement_Strategies__c IN :strategyIds];
        if (!resources.isEmpty()) {
            delete resources;
        }

        // Delete Strategies
        List<Strategies__c> strategyRecords = [SELECT Id FROM Strategies__c WHERE Abatement_Strategy__c IN :strategyIds];
        if (!strategyRecords.isEmpty()) {
            delete strategyRecords;
        }

        // Delete Abatement Strategies
        delete strategies;
    }

    public static void handleChildRecordsWithIds(List<Object> partnersData, List<Abatement_Strategy__c> abatementStrategies) {
        for (Integer i = 0; i < partnersData.size(); i++) {
            Object partnerObj = partnersData[i];
            String partnerJson = JSON.serialize(partnerObj);
            Map<String, Object> partner = (Map<String, Object>) JSON.deserializeUntyped(partnerJson);
            
            Abatement_Strategy__c currentAbatementStrategy = abatementStrategies[i];

            if (partner.containsKey('strategiesData') && partner.get('strategiesData') != null) {
                handleStrategyDataWithIds(partner, currentAbatementStrategy.Id);
            } else {
                deleteAllChildRecordsForStrategy(currentAbatementStrategy.Id);
            }
        }
    }

    private static void deleteAllChildRecordsForStrategy(Id abatementStrategyId) {
        // Delete Strategy Resources
        List<Strategy_Resources__c> resources = [SELECT Id FROM Strategy_Resources__c WHERE Abatement_Strategies__c = :abatementStrategyId];
        if (!resources.isEmpty()) {
            delete resources;
        }

        // Delete Strategies
        List<Strategies__c> strategies = [SELECT Id FROM Strategies__c WHERE Abatement_Strategy__c = :abatementStrategyId];
        if (!strategies.isEmpty()) {
            delete strategies;
        }
    }

    private static void handleStrategyDataWithIds(Map<String, Object> partner, Id abatementStrategyId) {
        Map<String, Object> strategiesData = (Map<String, Object>) partner.get('strategiesData');

        if (strategiesData.containsKey('strategyData') && strategiesData.get('strategyData') != null) {
            Object strategyDataObj = strategiesData.get('strategyData');
            String strategyDataJson = JSON.serialize(strategyDataObj);
            Map<String, Object> strategyData = (Map<String, Object>) JSON.deserializeUntyped(strategyDataJson);
            
            if (strategyData.isEmpty()) {
                deleteAllStrategiesForAbatementStrategy(abatementStrategyId);
                return;
            }
            
            Map<Id, Strategies__c> existingStrategies = new Map<Id, Strategies__c>(
                [SELECT Id, StrategiesName__c FROM Strategies__c WHERE Abatement_Strategy__c = :abatementStrategyId]
            );
            
            Set<Id> strategiesToKeep = new Set<Id>();
            List<Strategies__c> strategiesToUpsert = new List<Strategies__c>();

            for (String strategyKey : strategyData.keySet()) {
                Object strategyDetailsObj = strategyData.get(strategyKey);
                
                if (strategyDetailsObj == null) continue;
                
                String strategyDetailsJson = JSON.serialize(strategyDetailsObj);
                Map<String, Object> strategyDetails = (Map<String, Object>) JSON.deserializeUntyped(strategyDetailsJson);

                if (isEmptyStrategyDetails(strategyDetails)) {
                    continue;
                }

                Strategies__c strategyRecord = new Strategies__c();
                
                if (strategyDetails.containsKey('Id') && strategyDetails.get('Id') != null && String.valueOf(strategyDetails.get('Id')) != '') {
                    Id recordId = (Id) strategyDetails.get('Id');
                    strategyRecord.Id = recordId;
                    strategiesToKeep.add(recordId);
                }
                
                strategyRecord.Abatement_Strategy__c = abatementStrategyId;
                strategyRecord.StrategiesName__c = strategyKey;

                populateStrategyFields(strategyRecord, strategyDetails);
                strategiesToUpsert.add(strategyRecord);
            }

            List<Id> strategiesToDelete = new List<Id>();
            for (Id existingId : existingStrategies.keySet()) {
                if (!strategiesToKeep.contains(existingId)) {
                    strategiesToDelete.add(existingId);
                }
            }
            
            if (!strategiesToDelete.isEmpty()) {
                deleteSpecificStrategies(strategiesToDelete);
            }

            if (!strategiesToUpsert.isEmpty()) {
                upsert strategiesToUpsert;
                handleStrategyResourcesWithIds(strategiesData, strategiesToUpsert);
            } else {
                handleStrategyResourcesWithIds(strategiesData, new List<Strategies__c>());
            }
        } else {
            deleteAllStrategiesForAbatementStrategy(abatementStrategyId);
        }
    }

    // Helper method to check if strategy details are empty
    private static Boolean isEmptyStrategyDetails(Map<String, Object> strategyDetails) {
        if (strategyDetails == null || strategyDetails.isEmpty()) return true;
        
        // Check if any meaningful field has a value
        Boolean hasBudgetAmount = strategyDetails.containsKey('budgetAmount') && 
                                 strategyDetails.get('budgetAmount') != null && 
                                 String.valueOf(strategyDetails.get('budgetAmount')).trim() != '';
        
        Boolean hasInitialContinuation = strategyDetails.containsKey('isInitialContinuation') && 
                                        strategyDetails.get('isInitialContinuation') != null && 
                                        String.valueOf(strategyDetails.get('isInitialContinuation')).trim() != '';
        
        Boolean hasBudgetNarrative = strategyDetails.containsKey('budgetNarrative') && 
                                    strategyDetails.get('budgetNarrative') != null && 
                                    String.valueOf(strategyDetails.get('budgetNarrative')).trim() != '';
        
        Boolean hasImplementationPlan = strategyDetails.containsKey('implementationPlan') && 
                                       strategyDetails.get('implementationPlan') != null && 
                                       String.valueOf(strategyDetails.get('implementationPlan')).trim() != '';
        
        Boolean hasOutcomeMeasures = strategyDetails.containsKey('outcomeMeasures') && 
                                    strategyDetails.get('outcomeMeasures') != null && 
                                    String.valueOf(strategyDetails.get('outcomeMeasures')).trim() != '';
        
        Boolean hasProcessMeasures = strategyDetails.containsKey('processMeasures') && 
                                    strategyDetails.get('processMeasures') != null && 
                                    String.valueOf(strategyDetails.get('processMeasures')).trim() != '';
        
        return !(hasBudgetAmount || hasInitialContinuation || hasBudgetNarrative || 
                hasImplementationPlan || hasOutcomeMeasures || hasProcessMeasures);
    }

    private static void deleteAllStrategiesForAbatementStrategy(Id abatementStrategyId) {
        List<Strategies__c> strategies = [SELECT Id FROM Strategies__c WHERE Abatement_Strategy__c = :abatementStrategyId];
        if (!strategies.isEmpty()) {
            // Delete associated resources first
            List<Id> strategyIds = new List<Id>();
            for (Strategies__c strategy : strategies) {
                strategyIds.add(strategy.Id);
            }
            
            List<Strategy_Resources__c> resources = [SELECT Id FROM Strategy_Resources__c WHERE Abatement_Strategies__c = :abatementStrategyId];
            if (!resources.isEmpty()) {
                delete resources;
            }
            
            // Delete strategies
            delete strategies;
        }
    }

    private static void deleteSpecificStrategies(List<Id> strategyIds) {
        if (strategyIds.isEmpty()) return;
        
        // Get the abatement strategy IDs for the strategies being deleted
        List<Strategies__c> strategiesToDelete = [SELECT Id, Abatement_Strategy__c FROM Strategies__c WHERE Id IN :strategyIds];
        Set<Id> abatementStrategyIds = new Set<Id>();
        
        for (Strategies__c strategy : strategiesToDelete) {
            abatementStrategyIds.add(strategy.Abatement_Strategy__c);
        }
        
        // Delete related Strategy Resources for these abatement strategies
        List<Strategy_Resources__c> resources = [
            SELECT Id FROM Strategy_Resources__c 
            WHERE Abatement_Strategies__c IN :abatementStrategyIds
        ];
        
        if (!resources.isEmpty()) {
            delete resources;
        }

        // Delete the strategies
        if (!strategiesToDelete.isEmpty()) {
            delete strategiesToDelete;
        }
    }

    private static void populateStrategyFields(Strategies__c strategyRecord, Map<String, Object> strategyDetails) {
        if (strategyDetails.containsKey('budgetAmount') && strategyDetails.get('budgetAmount') != null && String.valueOf(strategyDetails.get('budgetAmount')).trim() != '') {
            Object budgetAmountObj = strategyDetails.get('budgetAmount');
            strategyRecord.Budget_Amount_for_the_Purchase__c = Decimal.valueOf(String.valueOf(budgetAmountObj));
        }
        if (strategyDetails.containsKey('isInitialContinuation') && strategyDetails.get('isInitialContinuation') != null && String.valueOf(strategyDetails.get('isInitialContinuation')).trim() != '') {
            strategyRecord.Is_your_Strategy_Initial_Continuation__c = (String) strategyDetails.get('isInitialContinuation');
        }
        if (strategyDetails.containsKey('budgetNarrative') && strategyDetails.get('budgetNarrative') != null && String.valueOf(strategyDetails.get('budgetNarrative')).trim() != '') {
            strategyRecord.Budget_Narrative__c = (String) strategyDetails.get('budgetNarrative');
        }
        if (strategyDetails.containsKey('implementationPlan') && strategyDetails.get('implementationPlan') != null && String.valueOf(strategyDetails.get('implementationPlan')).trim() != '') {
            strategyRecord.Implementation_plan_for_the_Strategy__c = (String) strategyDetails.get('implementationPlan');
        }
        if (strategyDetails.containsKey('outcomeMeasures') && strategyDetails.get('outcomeMeasures') != null && String.valueOf(strategyDetails.get('outcomeMeasures')).trim() != '') {
            strategyRecord.Provide_the_Outcome_Measures__c = (String) strategyDetails.get('outcomeMeasures');
        }
        if (strategyDetails.containsKey('processMeasures') && strategyDetails.get('processMeasures') != null && String.valueOf(strategyDetails.get('processMeasures')).trim() != '') {
            strategyRecord.Provide_the_Process_Measures__c = (String) strategyDetails.get('processMeasures');
        }
    }

    private static void handleStrategyResourcesWithIds(Map<String, Object> strategiesData, List<Strategies__c> strategiesRecords) {
        Set<Id> abatementStrategyIds = new Set<Id>();
        for (Strategies__c strategy : strategiesRecords) {
            abatementStrategyIds.add(strategy.Abatement_Strategy__c);
        }

        if (!strategiesData.containsKey('strategyResourcesData') || strategiesData.get('strategyResourcesData') == null) {
            deleteAllResourcesForStrategies(abatementStrategyIds);
            return;
        }

        Object strategyResourcesDataObj = strategiesData.get('strategyResourcesData');
        String strategyResourcesJson = JSON.serialize(strategyResourcesDataObj);
        Map<String, Object> strategyResourcesData = (Map<String, Object>) JSON.deserializeUntyped(strategyResourcesJson);
        
        if (strategyResourcesData.isEmpty()) {
            deleteAllResourcesForStrategies(abatementStrategyIds);
            return;
        }
        
        Map<String, Strategies__c> strategyNameToRecord = new Map<String, Strategies__c>();
        Set<String> currentStrategyNames = new Set<String>();
        
        for (Strategies__c strategy : strategiesRecords) {
            strategyNameToRecord.put(strategy.StrategiesName__c, strategy);
            currentStrategyNames.add(strategy.StrategiesName__c);
        }

        Map<Id, Strategy_Resources__c> existingResources = new Map<Id, Strategy_Resources__c>(
            [SELECT Id, Strategy_Resources_Name__c, RecordTypeId 
             FROM Strategy_Resources__c 
             WHERE Abatement_Strategies__c IN :abatementStrategyIds]
        );

        Set<Id> resourcesToKeep = new Set<Id>();
        List<Strategy_Resources__c> resourcesToInsert = new List<Strategy_Resources__c>();
        List<Strategy_Resources__c> resourcesToUpdate = new List<Strategy_Resources__c>();

        for (String strategyKey : strategyResourcesData.keySet()) {
            Strategies__c relatedStrategy = strategyNameToRecord.get(strategyKey);
            if (relatedStrategy == null) continue;

            Object resourceDataObj = strategyResourcesData.get(strategyKey);
            if (resourceDataObj == null) continue;
            
            String resourceDataJson = JSON.serialize(resourceDataObj);
            Map<String, Object> resourceData = (Map<String, Object>) JSON.deserializeUntyped(resourceDataJson);

            if (resourceData.containsKey('personnel') && resourceData.get('personnel') != null) {
                List<Object> personnelList = (List<Object>) resourceData.get('personnel');
                if (personnelList != null && !personnelList.isEmpty()) {
                    for (Object personnelObj : personnelList) {
                        if (personnelObj == null) continue;
                        
                        String personnelJson = JSON.serialize(personnelObj);
                        Map<String, Object> personnel = (Map<String, Object>) JSON.deserializeUntyped(personnelJson);

                        // Skip if personnel data is empty
                        if (isEmptyPersonnelData(personnel)) continue;

                        Strategy_Resources__c personnelResource = new Strategy_Resources__c();
                        
                        personnelResource.Abatement_Strategies__c = relatedStrategy.Abatement_Strategy__c;
                        personnelResource.RecordTypeId = getRecordTypeId('Strategy_Resources__c', 'personnel');
                        personnelResource.Strategy_Resources_Name__c = strategyKey;

                        populatePersonnelFields(personnelResource, personnel);
                        
                        if (personnel.containsKey('Id') && personnel.get('Id') != null && String.valueOf(personnel.get('Id')) != '') {
                            Id recordId = (Id) personnel.get('Id');
                            // Verify the record still exists and hasn't been deleted
                            if (existingResources.containsKey(recordId)) {
                                personnelResource.Id = recordId;
                                resourcesToKeep.add(recordId);
                                resourcesToUpdate.add(personnelResource);
                            } else {
                                // Record was deleted or doesn't exist, treat as insert
                                resourcesToInsert.add(personnelResource);
                            }
                        } else {
                            resourcesToInsert.add(personnelResource);
                        }
                    }
                }
            }

            // Process budget data
            if (resourceData.containsKey('budget') && resourceData.get('budget') != null) {
                List<Object> budgetList = (List<Object>) resourceData.get('budget');
                if (budgetList != null && !budgetList.isEmpty()) {
                    for (Object budgetObj : budgetList) {
                        if (budgetObj == null) continue;
                        
                        String budgetJson = JSON.serialize(budgetObj);
                        Map<String, Object> budget = (Map<String, Object>) JSON.deserializeUntyped(budgetJson);

                        // Skip if budget data is empty
                        if (isEmptyBudgetData(budget)) continue;

                        Strategy_Resources__c budgetResource = new Strategy_Resources__c();
                        
                        budgetResource.Abatement_Strategies__c = relatedStrategy.Abatement_Strategy__c;
                        budgetResource.RecordTypeId = getRecordTypeId('Strategy_Resources__c', 'budget');
                        budgetResource.Strategy_Resources_Name__c = strategyKey;

                        populateBudgetFields(budgetResource, budget);
                        
                        // Check if this is an update or insert
                        if (budget.containsKey('Id') && budget.get('Id') != null && String.valueOf(budget.get('Id')) != '') {
                            Id recordId = (Id) budget.get('Id');
                            // Verify the record still exists and hasn't been deleted
                            if (existingResources.containsKey(recordId)) {
                                budgetResource.Id = recordId;
                                resourcesToKeep.add(recordId);
                                resourcesToUpdate.add(budgetResource);
                            } else {
                                // Record was deleted or doesn't exist, treat as insert
                                resourcesToInsert.add(budgetResource);
                            }
                        } else {
                            resourcesToInsert.add(budgetResource);
                        }
                    }
                }
            }
        }

        // Delete resources that are no longer in the data
        List<Id> resourcesToDelete = new List<Id>();
        for (Id existingId : existingResources.keySet()) {
            if (!resourcesToKeep.contains(existingId)) {
                resourcesToDelete.add(existingId);
            }
        }
        
        if (!resourcesToDelete.isEmpty()) {
            List<Strategy_Resources__c> resourcesToDeleteList = [SELECT Id FROM Strategy_Resources__c WHERE Id IN :resourcesToDelete];
            if (!resourcesToDeleteList.isEmpty()) {
                delete resourcesToDeleteList;
            }
        }

        // Perform separate insert and update operations
        if (!resourcesToInsert.isEmpty()) {
            insert resourcesToInsert;
        }
        
        if (!resourcesToUpdate.isEmpty()) {
            update resourcesToUpdate;
        }
    }

    // Helper method to check if personnel data is empty
    private static Boolean isEmptyPersonnelData(Map<String, Object> personnel) {
        if (personnel == null || personnel.isEmpty()) return true;
        
        Boolean hasName = personnel.containsKey('name') && 
                         personnel.get('name') != null && 
                         String.valueOf(personnel.get('name')).trim() != '';
        
        Boolean hasPosition = personnel.containsKey('position') && 
                             personnel.get('position') != null && 
                             String.valueOf(personnel.get('position')).trim() != '';
        
        Boolean hasSalary = personnel.containsKey('salary') && 
                           personnel.get('salary') != null && 
                           String.valueOf(personnel.get('salary')).trim() != '';
        
        Boolean hasEffort = personnel.containsKey('effort') && 
                           personnel.get('effort') != null && 
                           String.valueOf(personnel.get('effort')).trim() != '';
        
        Boolean hasTotal = personnel.containsKey('total') && 
                          personnel.get('total') != null && 
                          String.valueOf(personnel.get('total')).trim() != '';
        
        return !(hasName || hasPosition || hasSalary || hasEffort || hasTotal);
    }

    // Helper method to check if budget data is empty
    private static Boolean isEmptyBudgetData(Map<String, Object> budget) {
        if (budget == null || budget.isEmpty()) return true;
        
        Boolean hasItem = budget.containsKey('item') && 
                         budget.get('item') != null && 
                         String.valueOf(budget.get('item')).trim() != '';
        
        Boolean hasPurpose = budget.containsKey('purpose') && 
                            budget.get('purpose') != null && 
                            String.valueOf(budget.get('purpose')).trim() != '';
        
        Boolean hasCalculation = budget.containsKey('calculation') && 
                                budget.get('calculation') != null && 
                                String.valueOf(budget.get('calculation')).trim() != '';
        
        Boolean hasTotal = budget.containsKey('total') && 
                          budget.get('total') != null && 
                          String.valueOf(budget.get('total')).trim() != '';
        
        return !(hasItem || hasPurpose || hasCalculation || hasTotal);
    }

    private static void deleteAllResourcesForStrategies(Set<Id> abatementStrategyIds) {
        if (abatementStrategyIds.isEmpty()) return;
        
        List<Strategy_Resources__c> resourcesToDelete = [
            SELECT Id FROM Strategy_Resources__c 
            WHERE Abatement_Strategies__c IN :abatementStrategyIds
        ];
        
        if (!resourcesToDelete.isEmpty()) {
            delete resourcesToDelete;
        }
    }

    private static void populatePersonnelFields(Strategy_Resources__c personnelResource, Map<String, Object> personnel) {
        if (personnel.containsKey('name') && personnel.get('name') != null && String.valueOf(personnel.get('name')).trim() != '') {
            personnelResource.PersonnelName__c = (String) personnel.get('name');
        }
        if (personnel.containsKey('position') && personnel.get('position') != null && String.valueOf(personnel.get('position')).trim() != '') {
            personnelResource.PersonnelPosition__c = (String) personnel.get('position');
        }
        if (personnel.containsKey('salary') && personnel.get('salary') != null && String.valueOf(personnel.get('salary')).trim() != '') {
            Object salaryObj = personnel.get('salary');
            personnelResource.PersonnelKeyStaffAnnualSalary__c = Decimal.valueOf(String.valueOf(salaryObj));
        }
        if (personnel.containsKey('effort') && personnel.get('effort') != null && String.valueOf(personnel.get('effort')).trim() != '') {
            personnelResource.PersonnelLevelOfEffort__c = (String) personnel.get('effort');
        }
        if (personnel.containsKey('total') && personnel.get('total') != null && String.valueOf(personnel.get('total')).trim() != '') {
            Object totalObj = personnel.get('total');
            personnelResource.PersonnelTotalChargedToAward__c = Decimal.valueOf(String.valueOf(totalObj));
        }
    }

    private static void populateBudgetFields(Strategy_Resources__c budgetResource, Map<String, Object> budget) {
        if (budget.containsKey('item') && budget.get('item') != null && String.valueOf(budget.get('item')).trim() != '') {
            budgetResource.BudgetItem__c = (String) budget.get('item');
        }
        if (budget.containsKey('purpose') && budget.get('purpose') != null && String.valueOf(budget.get('purpose')).trim() != '') {
            budgetResource.BudgetPurpose__c = (String) budget.get('purpose');
        }
        if (budget.containsKey('calculation') && budget.get('calculation') != null && String.valueOf(budget.get('calculation')).trim() != '') {
            budgetResource.BudgetCalculation__c = (String) budget.get('calculation');
        }
        if (budget.containsKey('total') && budget.get('total') != null && String.valueOf(budget.get('total')).trim() != '') {
            Object totalObj = budget.get('total');
            budgetResource.BudgetTotalChargedToAward__c = Decimal.valueOf(String.valueOf(totalObj));
        }
    }

    private static Id getRecordTypeId(String objectName, String recordTypeName) {
        try {
            return Schema.getGlobalDescribe().get(objectName).getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            System.debug('Error getting record type: ' + e.getMessage());
            return null;
        }
    }
}