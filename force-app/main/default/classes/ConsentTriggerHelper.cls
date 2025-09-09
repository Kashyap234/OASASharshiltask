public with sharing class ConsentTriggerHelper {
    public static void handleConsentFormApproval(List<ConsentForm__c> consentForms, Map<Id, ConsentForm__c> oldMap) {
        List<ConsentForm__c> approvedForms = new List<ConsentForm__c>();
        
        for (ConsentForm__c consentForm : consentForms) {
            boolean statusChanged = (oldMap == null) || 
                                  (oldMap.get(consentForm.Id).Consent_Status__c != consentForm.Consent_Status__c);
            
            if (statusChanged && consentForm.Consent_Status__c == 'Approved') {
                approvedForms.add(consentForm);
            }
        }
        
        if (!approvedForms.isEmpty()) {
            for (ConsentForm__c form : approvedForms) {
                calloutGoogleSheet(form.Id);
            }
        }
    }

    @future(callout=true)
    public static void calloutGoogleSheet(String recordId){
        try {
            ConsentForm__c consentForm = [SELECT Id, Student__c FROM ConsentForm__c WHERE Id = :recordId LIMIT 1];
            Student__c student = [SELECT Id, Name, Student_ID__c FROM Student__c WHERE Id = :consentForm.Student__c LIMIT 1];

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://script.google.com/macros/s/AKfycby5yEk1tlZMosgwdinxDDMH1sre5iPdFWJSnL-6DOgR-MQaCgXINa5NaOcddVfx_gI4/exec?id=' + student.Student_ID__c); 
            request.setMethod('GET'); 
            request.setHeader('Content-Type', 'application/json');
            
            HttpResponse response = http.send(request);
            while (response.getStatusCode() == 302) {
                request.setEndpoint(response.getHeader('Location'));
                response = http.send(request);
            }
            
            if (response.getStatusCode() == 200) {
                System.debug('Callout successful: ' + response.getBody());
                createAssessmentRecord(response.getBody(), student.Id);
            } else {
                System.debug('Callout failed with status code: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error in calloutGoogleSheet: ' + e.getMessage());
        }
    }
    
    private static void createAssessmentRecord(String responseBody, String studentId) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            if (responseMap.containsKey('data') && responseMap.get('status') == 200) {
                Map<String, Object> dataWrapper = (Map<String, Object>) responseMap.get('data');
                Map<String, Object> studentData = (Map<String, Object>) dataWrapper.get('data');
                
                Assessment__c assessment = new Assessment__c();
                assessment.Student__c = studentId; 
                
                if (studentData.containsKey('Attendance')) {
                    assessment.Attendance__c = String.valueOf(studentData.get('Attendance'));
                }
                
                if (studentData.containsKey('Grade')) {
                    assessment.Grade__c = String.valueOf(studentData.get('Grade'));
                }
                
                if (studentData.containsKey('Performance Level')) {
                    assessment.Performance_Level__c = String.valueOf(studentData.get('Performance Level'));
                }
                
                if (studentData.containsKey('Teacher\'s Rating')) {
                    assessment.Teacher_s_Rating__c = String.valueOf(studentData.get('Teacher\'s Rating'));
                }

                if(studentData.containsKey('Disciplinary Incidents')) {
                    assessment.Disciplinary_Incidents__c = String.valueOf(studentData.get('Disciplinary Incidents'));
                }

                if (studentData.containsKey('Enrollment Date')) {
                    assessment.Enrollment_Date__c = String.valueOf(studentData.get('Enrollment Date'));
                }
                
                insert assessment;
                System.debug('Assessment record created successfully: ' + assessment.Id);
            } else {
                System.debug('Invalid response format or unsuccessful status');
            }
        } catch (Exception e) {
            System.debug('Error creating Assessment record: ' + e.getMessage());
        }
    }
}