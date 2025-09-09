public with sharing class GPSApplicationGetDataHelper {
    
    public static Map<String, Object> getFundingApplication(Id applicationId) {
        try {
            List<String> fieldNames = new List<String>();
            for (Schema.FieldSetMember fsm : Schema.SObjectType.Funding_Application__c.fieldSets.Field_Display.getFields()) {
                fieldNames.add(fsm.getFieldPath());
            }

            if (!fieldNames.contains('Id')) fieldNames.add('Id');
            if (!fieldNames.contains('OwnerId')) fieldNames.add('OwnerId');

            if (fieldNames.isEmpty()) {
                throw new AuraHandledException('The "Field_Display" field set is not configured or is empty.');
            }

            String query = 'SELECT ' + String.join(fieldNames, ', ') + 
                           ' FROM Funding_Application__c WHERE Id = :applicationId LIMIT 1';

            System.debug('Query: ' + query);

            List<Funding_Application__c> applications = Database.query(query);
            
            if (applications.isEmpty()) {
                throw new AuraHandledException('Application not found or you do not have permission to view it.');
            }

            Funding_Application__c app = applications[0];
            Map<String, Object> applicationData = new Map<String, Object>();

            for (String fieldName : fieldNames) {
                Object fieldValue = app.get(fieldName);
                if (fieldValue != null) {
                    if (fieldValue instanceof Date) {
                        applicationData.put(fieldName, ((Date) fieldValue).format());
                    } else if (fieldName.equals('Please_select_the_appropriate_county__c') && fieldValue instanceof String) {
                        String stringValue = (String) fieldValue;
                        if (stringValue.contains(';')) {
                            applicationData.put(fieldName, stringValue.split(';'));
                        } else {
                            applicationData.put(fieldName, new List<String>{stringValue});
                        }
                    } else {
                        applicationData.put(fieldName, fieldValue);
                    }
                }
            }

            applicationData.put('UploadedFiles', getUploadedFiles(applicationId));
            applicationData.put('Partners', getPartnersData(applicationId));

            return applicationData;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving funding application: ' + e.getMessage() + 'Line: ' + e.getLineNumber());
        }
    }

    private static List<Map<String, Object>> getUploadedFiles(Id applicationId) {
        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :applicationId
        ];
        
        List<Map<String, Object>> uploadedFiles = new List<Map<String, Object>>();
        for (ContentDocumentLink link : docLinks) {
            Map<String, Object> fileInfo = new Map<String, Object>();
            fileInfo.put('documentId', link.ContentDocumentId);
            fileInfo.put('name', link.ContentDocument.Title);
            fileInfo.put('type', link.ContentDocument.FileType);
            uploadedFiles.add(fileInfo);
        }
        return uploadedFiles;
    }

    private static List<Map<String, Object>> getPartnersData(Id applicationId) {
        List<Abatement_Strategy__c> abatementStrategies = [
            SELECT Id, Partner_Name__c, Describe_Current_Budget_and_Funding_Sour__c,
                   Geographic_Area_Population_Poverty__c, Outline_Existing_Efforts_and_New_Expansi__c,
                   Core_Strategies__c, Core_Abatement_Strategies__c, Approved_Uses__c, Approved_Abatement_Strategies__c
            FROM Abatement_Strategy__c 
            WHERE Funding_Application__c = :applicationId
            ORDER BY CreatedDate
        ];

        List<Map<String, Object>> partners = new List<Map<String, Object>>();

        for (Abatement_Strategy__c strategy : abatementStrategies) {
            Map<String, Object> partner = new Map<String, Object>();
            // Include the actual Salesforce record ID instead of sequential number
            partner.put('RecordId', strategy.Id);
            partner.put('Partner_Name__c', strategy.Partner_Name__c);
            partner.put('Describe_Current_Budget_and_Funding_Sour__c', strategy.Describe_Current_Budget_and_Funding_Sour__c);
            partner.put('Geographic_Area_Population_Poverty__c', strategy.Geographic_Area_Population_Poverty__c);
            partner.put('Outline_Existing_Efforts_and_New_Expansi__c', strategy.Outline_Existing_Efforts_and_New_Expansi__c);

            Map<String, Object> strategiesData = getStrategiesData(strategy);
            partner.put('strategiesData', strategiesData);
            partners.add(partner);
        }

        return partners;
    }

    private static Map<String, Object> getStrategiesData(Abatement_Strategy__c strategy) {
        Map<String, Object> strategiesData = new Map<String, Object>();
        
        if (strategy.Core_Strategies__c != null) {
            strategiesData.put('selectedCoreStrategies', strategy.Core_Strategies__c.split(';'));
        } else {
            strategiesData.put('selectedCoreStrategies', new List<String>());
        }
        
        if (strategy.Core_Abatement_Strategies__c != null) {
            strategiesData.put('selectedCoreAbatements', strategy.Core_Abatement_Strategies__c.split(';'));
        } else {
            strategiesData.put('selectedCoreAbatements', new List<String>());
        }

        if (strategy.Approved_Uses__c != null) {
            strategiesData.put('selectedApprovedUses', strategy.Approved_Uses__c.split(';'));
        } else {
            strategiesData.put('selectedApprovedUses', new List<String>());
        }

        if (strategy.Approved_Abatement_Strategies__c != null) {
            strategiesData.put('selectedApprovedAbatements', strategy.Approved_Abatement_Strategies__c.split(';'));
        } else {
            strategiesData.put('selectedApprovedAbatements', new List<String>());
        }

        strategiesData.put('strategyData', getDetailedStrategyData(strategy.Id));
        strategiesData.put('strategyResourcesData', getStrategyResourcesData(strategy.Id));

        return strategiesData;
    }

    private static Map<String, Object> getDetailedStrategyData(Id strategyId) {
        List<Strategies__c> strategies = [
            SELECT Id, StrategiesName__c, Budget_Amount_for_the_Purchase__c,
                   Is_your_Strategy_Initial_Continuation__c, Budget_Narrative__c,
                   Implementation_plan_for_the_Strategy__c, Provide_the_Outcome_Measures__c,
                   Provide_the_Process_Measures__c
            FROM Strategies__c 
            WHERE Abatement_Strategy__c = :strategyId
        ];

        Map<String, Object> strategyData = new Map<String, Object>();
        for (Strategies__c strat : strategies) {
            Map<String, Object> stratDetails = new Map<String, Object>();
            // Include the actual Salesforce record ID
            stratDetails.put('Id', strat.Id);
            stratDetails.put('budgetAmount', strat.Budget_Amount_for_the_Purchase__c);
            stratDetails.put('isInitialContinuation', strat.Is_your_Strategy_Initial_Continuation__c);
            stratDetails.put('budgetNarrative', strat.Budget_Narrative__c);
            stratDetails.put('implementationPlan', strat.Implementation_plan_for_the_Strategy__c);
            stratDetails.put('outcomeMeasures', strat.Provide_the_Outcome_Measures__c);
            stratDetails.put('processMeasures', strat.Provide_the_Process_Measures__c);
            strategyData.put(strat.StrategiesName__c, stratDetails);
        }
        
        return strategyData;
    }

    private static Map<String, Object> getStrategyResourcesData(Id strategyId) {
        List<Strategy_Resources__c> resources = [
            SELECT Id, RecordType.Name, Strategy_Resources_Name__c,
                   PersonnelName__c, PersonnelPosition__c, PersonnelKeyStaffAnnualSalary__c,
                   PersonnelLevelOfEffort__c, PersonnelTotalChargedToAward__c,
                   BudgetItem__c, BudgetPurpose__c, BudgetCalculation__c, BudgetTotalChargedToAward__c
            FROM Strategy_Resources__c 
            WHERE Abatement_Strategies__c = :strategyId
        ];

        Map<String, Object> strategyResourcesData = new Map<String, Object>();
        
        for (Strategy_Resources__c resource : resources) {
            String strategyName = resource.Strategy_Resources_Name__c;
            
            if (!strategyResourcesData.containsKey(strategyName)) {
                Map<String, Object> resourceData = new Map<String, Object>();
                resourceData.put('personnel', new List<Map<String, Object>>());
                resourceData.put('budget', new List<Map<String, Object>>());
                strategyResourcesData.put(strategyName, resourceData);
            }

            Map<String, Object> resourceData = (Map<String, Object>) strategyResourcesData.get(strategyName);

            if (resource.RecordType.Name == 'personnel') {
                List<Map<String, Object>> personnel = (List<Map<String, Object>>) resourceData.get('personnel');
                Map<String, Object> personnelItem = new Map<String, Object>();
                // Include the actual Salesforce record ID
                personnelItem.put('Id', resource.Id);
                personnelItem.put('name', resource.PersonnelName__c);
                personnelItem.put('position', resource.PersonnelPosition__c);
                personnelItem.put('salary', resource.PersonnelKeyStaffAnnualSalary__c);
                personnelItem.put('effort', resource.PersonnelLevelOfEffort__c);
                personnelItem.put('total', resource.PersonnelTotalChargedToAward__c);
                personnel.add(personnelItem);
            } else if (resource.RecordType.Name == 'budget') {
                List<Map<String, Object>> budget = (List<Map<String, Object>>) resourceData.get('budget');
                Map<String, Object> budgetItem = new Map<String, Object>();
                // Include the actual Salesforce record ID
                budgetItem.put('Id', resource.Id);
                budgetItem.put('item', resource.BudgetItem__c);
                budgetItem.put('purpose', resource.BudgetPurpose__c);
                budgetItem.put('calculation', resource.BudgetCalculation__c);
                budgetItem.put('total', resource.BudgetTotalChargedToAward__c);
                budget.add(budgetItem);
            }
        }

        return strategyResourcesData;
    }

    public static User getCurrentUser() {
        try {
            return [
                SELECT Id, Name, Email, Phone
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving user information: ' + e.getMessage());
        }
    }
}