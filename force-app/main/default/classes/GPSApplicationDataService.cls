public with sharing class GPSApplicationDataService {
    public static Boolean isApplicationOpen() {
        List<Application_Timeline__c> timelineList = [SELECT Id FROM Application_Timeline__c WHERE Program__c = 'GPS' AND Is_Application_Open__c = true LIMIT 1];
        return !timelineList.isEmpty();
    }

    public static Id createFundingApplication(Map<String, Object> applicationData) {
        try {
            Funding_Application__c newApplication = new Funding_Application__c();

            // if(existingApplication.Application_Status__c != 'Draft' && existingApplication.Application_Status__c != 'Revisions requested') {
            //     throw new AuraHandledException('Cannot update a submitted application.');
            // }

            if(applicationData == null || applicationData.isEmpty()) {
                throw new AuraHandledException('No application data provided for update.');
            }

            ServiceUtility.ApplicationResult result = ServiceUtility.checkApplicationEligibility(UserInfo.getUserId());

            if(!result.isEligibleToApply) {
                throw new AuraHandledException(result.message);
            }

            newApplication.Application_Timeline__c = result.currentTimeline.Id;

            populateApplicationFields(newApplication, applicationData);
            newApplication.OwnerId = UserInfo.getUserId();
            
            insert newApplication;
            
            handleRelatedDataWithIds(newApplication.Id, applicationData);

            return newApplication.Id;
        } catch (AuraHandledException ahe) {

            System_Event__c event = new System_Event__c();
            event.Exception_Type__c = 'AuraHandledException';
            event.Message__c = ahe.getMessage();
            event.Line_Number__c = String.valueOf(ahe.getLineNumber());
            event.Complete_Trace__c = ahe.getStackTraceString();
            event.Component_Name__c = 'GPSApplicationDataService.createFundingApplication';
            event.Component_Type__c = 'Apex Class';

            insert event;

            throw ahe; 
        }
        catch (Exception e) {
            throw new AuraHandledException('Error creating funding application: ' + e.getMessage());
        }
    }

    public static Id updateFundingApplication(Id applicationId, Map<String, Object> applicationData) {
        try {
            Funding_Application__c existingApplication = [SELECT Id, Application_Status__c FROM Funding_Application__c WHERE Id = :applicationId AND OwnerId = :UserInfo.getUserId() LIMIT 1];
            
            if(existingApplication.Application_Status__c != 'Draft' && existingApplication.Application_Status__c != 'Revisions requested') {
                throw new AuraHandledException('Cannot update a submitted application.');
            }

            if(applicationData == null || applicationData.isEmpty()) {
                throw new AuraHandledException('No application data provided for update.');
            }

            ServiceUtility.ApplicationResult result = ServiceUtility.checkApplicationEligibility(UserInfo.getUserId());

            if(!result.isEligibleToApply) {
                throw new AuraHandledException(result.message);
            }

            existingApplication.Application_Timeline__c = result.currentTimeline.Id;

            populateApplicationFields(existingApplication, applicationData);
            update existingApplication;
            
            handleRelatedDataWithIds(applicationId, applicationData);

            return applicationId;
        } catch (AuraHandledException ahe) {
            
            System_Event__c event = new System_Event__c(
                Exception_Type__c = 'AuraHandledException',
                Message__c = ahe.getMessage(),
                Line_Number__c = String.valueOf(ahe.getLineNumber()),
                Complete_Trace__c = ahe.getStackTraceString(),
                Component_Name__c = 'GPSApplicationDataService.updateFundingApplication',
                Component_Type__c = 'Apex Class'
            );

            insert event;
            System.debug('Event Id: ' + event.Id);

            System.debug('Error updating funding application: ' + ahe.getMessage());
            
            throw ahe; 
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating funding application: ' + e.getMessage() + 'Trace: ' + e.getStackTraceString());
        }
    }

    private static void populateApplicationFields(Funding_Application__c application, Map<String, Object> applicationData) {
        for (String fieldName : applicationData.keySet()) {
            Object fieldValue = applicationData.get(fieldName);

            if (fieldName != 'UploadedFiles' && fieldName != 'Partners') {
                if (fieldValue == null || fieldValue == '') {
                    application.put(fieldName, null);
                } else if (fieldName.contains('Date') && fieldValue instanceof String) {
                    application.put(fieldName, Date.valueOf((String) fieldValue));
                } else if (fieldName.contains('Currency') || fieldName.contains('Amount') || fieldName.contains('Budget') || fieldName.contains('Minus_Estimated_Interest_Earned__c')) {
                    application.put(fieldName, Decimal.valueOf(String.valueOf(fieldValue)));
                } else if (fieldName.equals('Please_select_the_appropriate_county__c')) {
                    if (fieldValue instanceof List<Object>) {
                        List<Object> values = (List<Object>) fieldValue;
                        application.put(fieldName, String.join(values, ';'));
                    } else {
                        application.put(fieldName, String.valueOf(fieldValue));
                    }
                } else {
                    application.put(fieldName, fieldValue);
                }
            } 
        }
    }

    private static void handleRelatedDataWithIds(Id applicationId, Map<String, Object> applicationData) {
        handleUploadedFiles(applicationData, applicationId);
        handlePartnersDataWithIds(applicationData, applicationId);
    }

    private static void handleUploadedFiles(Map<String, Object> applicationData, Id applicationId) {
        if (!applicationData.containsKey('UploadedFiles') || applicationData.get('UploadedFiles') == null) {
            deleteExistingContentDocumentLinks(applicationId);
            return;
        }

        List<Object> uploadedFiles = (List<Object>)applicationData.get('UploadedFiles');
        
        Map<String, ContentDocumentLink> existingLinks = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink link : [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :applicationId]) {
            existingLinks.put(link.ContentDocumentId, link);
        }

        Set<String> filesToKeep = new Set<String>();
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

        for (Object fileObj : uploadedFiles) {
            String fileJson = JSON.serialize(fileObj);
            Map<String, Object> fileMap = (Map<String, Object>) JSON.deserializeUntyped(fileJson);
            
            if (fileMap.containsKey('documentId')) {
                String contentDocumentId = (String)fileMap.get('documentId');
                filesToKeep.add(contentDocumentId);
                
                if (!existingLinks.containsKey(contentDocumentId)) {
                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = contentDocumentId,
                        LinkedEntityId = applicationId,
                        ShareType = 'V', 
                        Visibility = 'AllUsers'
                    ));
                }
            }
        }

        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        for (String existingDocId : existingLinks.keySet()) {
            if (!filesToKeep.contains(existingDocId)) {
                linksToDelete.add(existingLinks.get(existingDocId));
            }
        }

        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }
        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }
    }

    private static void deleteExistingContentDocumentLinks(Id applicationId) {
        List<ContentDocumentLink> existingLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :applicationId];
        if (!existingLinks.isEmpty()) {
            delete existingLinks;
        }
    }

    private static void handlePartnersDataWithIds(Map<String, Object> applicationData, Id applicationId) {
        if (!applicationData.containsKey('Partners') || 
            applicationData.get('Partners') == null || 
            isEmptyPartnersList(applicationData.get('Partners'))) {
            GPSApplicationDataServiceHelper.deleteExistingPartnersData(applicationId);
            return;
        }

        List<Object> partnersData = (List<Object>) applicationData.get('Partners');
        
        List<Object> validPartnersData = filterValidPartners(partnersData);
        
        if (validPartnersData.isEmpty()) {
            GPSApplicationDataServiceHelper.deleteExistingPartnersData(applicationId);
            return;
        }
        
        Map<Id, Abatement_Strategy__c> existingStrategies = new Map<Id, Abatement_Strategy__c>(
            [SELECT Id FROM Abatement_Strategy__c WHERE Funding_Application__c = :applicationId]
        );
        
        Set<Id> strategiesToKeep = new Set<Id>();
        List<Abatement_Strategy__c> strategiesToUpsert = new List<Abatement_Strategy__c>();

        for (Object partnerObj : validPartnersData) {
            String partnerJson = JSON.serialize(partnerObj);
            Map<String, Object> partner = (Map<String, Object>) JSON.deserializeUntyped(partnerJson);

            if (isEmptyPartnerData(partner)) {
                continue;
            }

            Abatement_Strategy__c abatementStrategy = new Abatement_Strategy__c();
            
            if (partner.containsKey('RecordId') && partner.get('RecordId') != null && String.valueOf(partner.get('RecordId')) != '') {
                Id recordId = (Id) partner.get('RecordId');
                abatementStrategy.Id = recordId;
                strategiesToKeep.add(recordId);
            }
            
            abatementStrategy.Funding_Application__c = applicationId;
            
            GPSApplicationDataServiceHelper.populateAbatementStrategyFields(abatementStrategy, partner);
            strategiesToUpsert.add(abatementStrategy);
        }

        // Delete that no longer in the partners
        List<Id> strategiesToDelete = new List<Id>();
        for (Id existingId : existingStrategies.keySet()) {
            if (!strategiesToKeep.contains(existingId)) {
                strategiesToDelete.add(existingId);
            }
        }
        
        if (!strategiesToDelete.isEmpty()) {
            GPSApplicationDataServiceHelper.deleteSpecificAbatementStrategies(strategiesToDelete);
        }

        if (!strategiesToUpsert.isEmpty()) {
            upsert strategiesToUpsert;
            
            GPSApplicationDataServiceHelper.handleChildRecordsWithIds(validPartnersData, strategiesToUpsert);
        }
    }

    private static Boolean isEmptyPartnersList(Object partnersObj) {
        if (partnersObj == null) return true;
        
        try {
            List<Object> partnersList = (List<Object>) partnersObj;
            if (partnersList.isEmpty()) return true;
            
            for (Object partner : partnersList) {
                String partnerJson = JSON.serialize(partner);
                Map<String, Object> partnerMap = (Map<String, Object>) JSON.deserializeUntyped(partnerJson);
                if (!isEmptyPartnerData(partnerMap)) {
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            return true;
        }
    }

    private static Boolean isEmptyPartnerData(Map<String, Object> partner) {
        if (partner == null || partner.isEmpty()) return true;
        
        Boolean hasPartnerName = partner.containsKey('Partner_Name__c') && 
                                partner.get('Partner_Name__c') != null && 
                                String.valueOf(partner.get('Partner_Name__c')).trim() != '';
        
        Boolean hasBudgetDesc = partner.containsKey('Describe_Current_Budget_and_Funding_Sour__c') && 
                               partner.get('Describe_Current_Budget_and_Funding_Sour__c') != null && 
                               String.valueOf(partner.get('Describe_Current_Budget_and_Funding_Sour__c')).trim() != '';
        
        Boolean hasGeoArea = partner.containsKey('Geographic_Area_Population_Poverty__c') && 
                            partner.get('Geographic_Area_Population_Poverty__c') != null && 
                            String.valueOf(partner.get('Geographic_Area_Population_Poverty__c')).trim() != '';
        
        Boolean hasExistingEfforts = partner.containsKey('Outline_Existing_Efforts_and_New_Expansi__c') && 
                                    partner.get('Outline_Existing_Efforts_and_New_Expansi__c') != null && 
                                    String.valueOf(partner.get('Outline_Existing_Efforts_and_New_Expansi__c')).trim() != '';
        
        Boolean hasStrategiesData = false;
        if (partner.containsKey('strategiesData') && partner.get('strategiesData') != null) {
            try {
                String strategiesJson = JSON.serialize(partner.get('strategiesData'));
                Map<String, Object> strategiesData = (Map<String, Object>) JSON.deserializeUntyped(strategiesJson);
                hasStrategiesData = !isEmptyStrategiesData(strategiesData);
            } catch (Exception e) {
                hasStrategiesData = false;
            }
        }
        
        return !(hasPartnerName || hasBudgetDesc || hasGeoArea || hasExistingEfforts || hasStrategiesData);
    }

    private static Boolean isEmptyStrategiesData(Map<String, Object> strategiesData) {
        if (strategiesData == null || strategiesData.isEmpty()) return true;
        
        // Check if any strategy selections exist
        Boolean hasSelections = false;
        if (strategiesData.containsKey('selectedCoreStrategies')) {
            List<Object> coreStrategies = (List<Object>) strategiesData.get('selectedCoreStrategies');
            hasSelections = hasSelections || (coreStrategies != null && !coreStrategies.isEmpty());
        }
        
        if (strategiesData.containsKey('selectedCoreAbatements')) {
            List<Object> coreAbatements = (List<Object>) strategiesData.get('selectedCoreAbatements');
            hasSelections = hasSelections || (coreAbatements != null && !coreAbatements.isEmpty());
        }
        
        if (strategiesData.containsKey('selectedApprovedUses')) {
            List<Object> approvedUses = (List<Object>) strategiesData.get('selectedApprovedUses');
            hasSelections = hasSelections || (approvedUses != null && !approvedUses.isEmpty());
        }
        
        if (strategiesData.containsKey('selectedApprovedAbatements')) {
            List<Object> approvedAbatements = (List<Object>) strategiesData.get('selectedApprovedAbatements');
            hasSelections = hasSelections || (approvedAbatements != null && !approvedAbatements.isEmpty());
        }
        
        // Check if strategy data exists
        Boolean hasStrategyData = false;
        if (strategiesData.containsKey('strategyData') && strategiesData.get('strategyData') != null) {
            try {
                String strategyDataJson = JSON.serialize(strategiesData.get('strategyData'));
                Map<String, Object> strategyData = (Map<String, Object>) JSON.deserializeUntyped(strategyDataJson);
                hasStrategyData = !strategyData.isEmpty();
            } catch (Exception e) {
                hasStrategyData = false;
            }
        }
        
        return !(hasSelections || hasStrategyData);
    }

    private static List<Object> filterValidPartners(List<Object> partnersData) {
        List<Object> validPartners = new List<Object>();
        
        for (Object partnerObj : partnersData) {
            String partnerJson = JSON.serialize(partnerObj);
            Map<String, Object> partner = (Map<String, Object>) JSON.deserializeUntyped(partnerJson);
            
            if (!isEmptyPartnerData(partner)) {
                validPartners.add(partnerObj);
            }
        }
        
        return validPartners;
    }
}