public with sharing class ReferralFormJsonProcessor {
    
    public class FormSubmissionResponse {
        public Boolean success;
        public String message;
        public String referralFormId;
        public String studentDataId;
        public String schoolId;
        public Boolean studentDataCreated;
        public Boolean studentDataUpdated;
        public Boolean schoolCreated;
        public List<String> errors;
        public List<String> warnings;
        public String processingTime;
        
        public FormSubmissionResponse() {
            this.errors = new List<String>();
            this.warnings = new List<String>();
            this.studentDataCreated = false;
            this.studentDataUpdated = false;
            this.schoolCreated = false;
        }
    }
    
    // Constants for record types
    private static final String STUDENT_RECORD_TYPE = 'Student';
    private static final String INDIVIDUAL_ADULT_RECORD_TYPE = 'Individual_Adult';
    
    /**
     * Main method to process JSON data and create referral form
     * @param jsonData - JSON string containing referral form data
     * @return FormSubmissionResponse with processing results
     */
    @AuraEnabled
    public static FormSubmissionResponse processReferralFormJson(String jsonData) {
        FormSubmissionResponse response = new FormSubmissionResponse();
        DateTime startTime = DateTime.now();
        
        try {
            System.debug('Processing JSON Data: ' + jsonData);
            
            if (String.isBlank(jsonData)) {
                throw new ReferralFormException('Empty JSON data provided');
            }
            
            Map<String, Object> formData = parseJsonData(jsonData);
            Map<String, Object> referralFormDataMap = extractReferralFormData(formData);
            
            String referralType = (String) referralFormDataMap.get('What_type_of_referral_is_this__c');
            
            if ('Student or Family'.equals(referralType)) {
                processStudentReferral(referralFormDataMap, response);
            } else if ('Individual Adult and no students'.equals(referralType)) {
                processAdultReferral(referralFormDataMap, jsonData, response);
            } else {
                throw new ReferralFormException('Invalid referral type: ' + referralType);
            }
            
            // Create the referral form record
            Referral_Form__c newReferralForm = createReferralFormRecord(referralFormDataMap, response);
            response.referralFormId = newReferralForm.Id;
            
            response.success = true;
            response.message = 'Successfully created Referral Form record';
            
        } catch (ReferralFormException e) {
            handleReferralFormException(e, response);
        } catch (DmlException e) {
            handleDmlException(e, response);
        } catch (Exception e) {
            handleGeneralException(e, response);
        }
        
        // Calculate processing time
        DateTime endTime = DateTime.now();
        response.processingTime = (endTime.getTime() - startTime.getTime()) + 'ms';
        
        System.debug('=== Processing completed in ' + response.processingTime + ' ===');
        return response;
    }
    
    /**
     * Overloaded method that accepts Map directly
     * @param formDataMap - Map containing referral form data
     * @return FormSubmissionResponse with processing results
     */
    public static FormSubmissionResponse processReferralFormData(Map<String, Object> formDataMap) {
        if (formDataMap == null || formDataMap.isEmpty()) {
            FormSubmissionResponse errorResponse = new FormSubmissionResponse();
            errorResponse.success = false;
            errorResponse.message = 'Empty form data provided';
            errorResponse.errors.add('Form data map is null or empty');
            return errorResponse;
        }
        
        String jsonData = JSON.serialize(formDataMap);
        return processReferralFormJson(jsonData);
    }
    
    /**
     * Parse JSON string into Map
     */
    private static Map<String, Object> parseJsonData(String jsonData) {
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(jsonData);
        } catch (Exception e) {
            throw new ReferralFormException('Invalid JSON format: ' + e.getMessage());
        }
    }
    
    /**
     * Extract referral form data from the parsed JSON
     */
    private static Map<String, Object> extractReferralFormData(Map<String, Object> formData) {
        Map<String, Object> referralFormDataMap = (Map<String, Object>) formData.get('referralFormData');
        
        if (referralFormDataMap == null || referralFormDataMap.isEmpty()) {
            throw new ReferralFormException('No referral form data provided in JSON');
        }
        
        return referralFormDataMap;
    }
    
    /**
     * Process student referral type
     */
    private static void processStudentReferral(Map<String, Object> referralFormDataMap, FormSubmissionResponse response) {
        // Set record type
        Id recordTypeId = getRecordTypeId(STUDENT_RECORD_TYPE);
        if (recordTypeId != null) {
            referralFormDataMap.put('RecordTypeId', recordTypeId);
        }
        
        // Handle school lookup/creation
        String schoolId = handleSchoolLookupOrCreation(referralFormDataMap, response);
        
        // Handle student data lookup/creation
        String studentDataId = handleStudentDataLookupOrCreation(referralFormDataMap, response, schoolId);
        
        if (studentDataId != null) {
            referralFormDataMap.put('Student_Data__c', studentDataId);
            response.studentDataId = studentDataId;
        }
    }
    
    /**
     * Process adult referral type
     */
    private static void processAdultReferral(Map<String, Object> referralFormDataMap, String rawJsonData, FormSubmissionResponse response) {
        // Check for duplicate referrals
        if (handleDuplicateReferral(referralFormDataMap, rawJsonData, response)) {
            return; // Duplicate found, stop processing
        }
        
        // Set record type
        Id recordTypeId = getRecordTypeId(INDIVIDUAL_ADULT_RECORD_TYPE);
        if (recordTypeId != null) {
            referralFormDataMap.put('RecordTypeId', recordTypeId);
        }
        
        // Handle school lookup/creation
        String schoolId = handleSchoolLookupOrCreation(referralFormDataMap, response);
        if (schoolId != null) {
            referralFormDataMap.put('School__c', schoolId);
            response.schoolId = schoolId;
        }
    }
    
    /**
     * Handle duplicate referral detection for adult referrals
     */
    private static Boolean handleDuplicateReferral(Map<String, Object> referralFormDataMap, String rawJsonData, FormSubmissionResponse response) {
        try {
            String phone = getStringValue(referralFormDataMap, 'ParentGuardianAdultPhoneNumber__c');
            String email = getStringValue(referralFormDataMap, 'ParentGuardianAdultEmail__c');
            
            if (phone == null && email == null) {
                return false;
            }
            
            Decimal phoneAsNumber = phone != null ? Decimal.valueOf(phone) : null;
            Datetime sixMonthsAgo = Datetime.now().addMonths(-6);
            
            // Build dynamic SOQL query
            String soqlQuery = 'SELECT Id FROM Referral_Form__c WHERE CreatedDate >= :sixMonthsAgo';
            List<String> conditions = new List<String>();
            
            if (phone != null) {
                conditions.add('ParentGuardianAdultPhoneNumber__c = :phoneAsNumber');
            }
            if (email != null) {
                conditions.add('ParentGuardianAdultEmail__c = :email');
            }
            
            if (!conditions.isEmpty()) {
                soqlQuery += ' AND (' + String.join(conditions, ' OR ') + ') LIMIT 1';
                List<Referral_Form__c> existing = Database.query(soqlQuery);
                
                if (!existing.isEmpty()) {
                    // Create duplicate record
                    createDuplicateRecord(existing[0].Id, rawJsonData);
                    
                    response.success = false;
                    response.message = 'Duplicate referral found within last 6 months. Captured in Duplicate_Referral__c.';
                    response.warnings.add('Duplicate detected by phone/email within 6 months.');
                    return true;
                }
            }
            
            return false;
        } catch (Exception e) {
            System.debug('Error during duplicate referral handling: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Create duplicate referral record
     */
    private static void createDuplicateRecord(Id referralFormId, String jsonData) {
        try {
            Duplicate_Referral__c dup = new Duplicate_Referral__c();
            dup.Referral_Form__c = referralFormId;
            dup.JSON_Data__c = jsonData;
            insert dup;
        } catch (Exception e) {
            System.debug('Failed to insert Duplicate_Referral__c: ' + e.getMessage());
        }
    }
    
    /**
     * Get record type ID by developer name
     */
    private static Id getRecordTypeId(String recordTypeName) {
        if (String.isBlank(recordTypeName)) {
            return null;
        }
        
        try {
            List<RecordType> recordTypes = [
                SELECT Id FROM RecordType 
                WHERE SObjectType = 'Referral_Form__c' AND DeveloperName = :recordTypeName 
                LIMIT 1
            ];
            return recordTypes.isEmpty() ? null : recordTypes[0].Id;
        } catch (Exception e) {
            System.debug('Error retrieving record type: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Handle school lookup or creation
     */
    private static String handleSchoolLookupOrCreation(Map<String, Object> referralFormDataMap, FormSubmissionResponse response) {
        String schoolName = getStringValue(referralFormDataMap, 'School_Name__c');
        
        if (String.isBlank(schoolName)) {
            response.warnings.add('No School Name provided - will create Referral Form without School reference');
            return null;
        }
        
        try {
            List<School__c> existingSchools = [
                SELECT Id FROM School__c 
                WHERE SchoolName__c = :schoolName 
                LIMIT 1
            ];
            
            if (existingSchools.isEmpty()) {
                response.warnings.add('School not found: ' + schoolName + ' - will create Referral Form without School reference');
                return null;
            }
            
            System.debug('Found existing School: ' + existingSchools[0].Id);
            return existingSchools[0].Id;
            
        } catch (Exception e) {
            System.debug('Error in school lookup: ' + e.getMessage());
            response.warnings.add('Error querying School records: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Handle student data lookup or creation
     */
    private static String handleStudentDataLookupOrCreation(Map<String, Object> referralFormDataMap, FormSubmissionResponse response, String schoolId) {
        String studentIdStr = getStringValue(referralFormDataMap, 'StudentIDNumber__c');
        
        if (String.isBlank(studentIdStr)) {
            response.warnings.add('No Student ID Number provided - will create Referral Form without Student Data reference');
            return null;
        }
        
        try {
            Decimal studentIdNumber = Decimal.valueOf(studentIdStr);
            
            List<Student_Data__c> existingStudentData = [
                SELECT Id, Student_First_Name__c, Student_Last_Name__c, Date_of_Birth__c, 
                       Grade__c, Gender__c, School__c
                FROM Student_Data__c 
                WHERE Student_ID_Number__c = :studentIdNumber 
                LIMIT 1
            ];
            
            if (!existingStudentData.isEmpty()) {
                Student_Data__c existingStudent = existingStudentData[0];
                
                if (updateStudentDataFields(existingStudent, referralFormDataMap, schoolId)) {
                    update existingStudent;
                    response.studentDataUpdated = true;
                    response.warnings.add('Updated existing Student Data record with ID: ' + studentIdStr);
                }
                
                return existingStudent.Id;
            } else {
                // Create new student data
                Student_Data__c newStudentData = createStudentDataRecord(referralFormDataMap, schoolId, studentIdNumber);
                insert newStudentData;
                
                response.studentDataCreated = true;
                response.warnings.add('New Student Data record created with ID: ' + studentIdStr);
                return newStudentData.Id;
            }
            
        } catch (Exception e) {
            System.debug('Error in student data handling: ' + e.getMessage());
            response.errors.add('Error handling Student Data: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Create new student data record
     */
    private static Student_Data__c createStudentDataRecord(Map<String, Object> referralFormDataMap, String schoolId, Decimal studentIdNumber) {
        Student_Data__c newStudentData = new Student_Data__c();
        newStudentData.Student_ID_Number__c = studentIdNumber;
        
        setStudentDataFields(newStudentData, referralFormDataMap, schoolId);
        
        return newStudentData;
    }
    
    /**
     * Update existing student data fields if different
     */
    private static Boolean updateStudentDataFields(Student_Data__c existingStudent, Map<String, Object> referralFormDataMap, String schoolId) {
        Boolean needsUpdate = false;
        
        String newFirstName = getStringValue(referralFormDataMap, 'StudentFirstName__c');
        if (newFirstName != null && existingStudent.Student_First_Name__c != newFirstName) {
            existingStudent.Student_First_Name__c = newFirstName;
            needsUpdate = true;
        }
        
        String newLastName = getStringValue(referralFormDataMap, 'StudentLastName__c');
        if (newLastName != null && existingStudent.Student_Last_Name__c != newLastName) {
            existingStudent.Student_Last_Name__c = newLastName;
            needsUpdate = true;
        }
        
        Date newDob = getDateValue(referralFormDataMap, 'DateOfBirth__c');
        if (newDob != null && existingStudent.Date_of_Birth__c != newDob) {
            existingStudent.Date_of_Birth__c = newDob;
            needsUpdate = true;
        }
        
        String newGrade = getStringValue(referralFormDataMap, 'Grade__c');
        if (newGrade != null && existingStudent.Grade__c != newGrade) {
            existingStudent.Grade__c = newGrade;
            needsUpdate = true;
        }
        
        String newGender = getStringValue(referralFormDataMap, 'StudentGender__c');
        if (newGender != null && existingStudent.Gender__c != newGender) {
            existingStudent.Gender__c = newGender;
            needsUpdate = true;
        }
        
        if (schoolId != null && existingStudent.School__c != schoolId) {
            existingStudent.School__c = schoolId;
            needsUpdate = true;
        }
        
        return needsUpdate;
    }
    
    /**
     * Set student data fields from form data
     */
    private static void setStudentDataFields(Student_Data__c studentData, Map<String, Object> referralFormDataMap, String schoolId) {
        String firstName = getStringValue(referralFormDataMap, 'StudentFirstName__c');
        if (firstName != null) studentData.Student_First_Name__c = firstName;
        
        String lastName = getStringValue(referralFormDataMap, 'StudentLastName__c');
        if (lastName != null) studentData.Student_Last_Name__c = lastName;
        
        Date dob = getDateValue(referralFormDataMap, 'DateOfBirth__c');
        if (dob != null) studentData.Date_of_Birth__c = dob;
        
        String grade = getStringValue(referralFormDataMap, 'Grade__c');
        if (grade != null) studentData.Grade__c = grade;
        
        String gender = getStringValue(referralFormDataMap, 'StudentGender__c');
        if (gender != null) studentData.Gender__c = gender;
        
        if (schoolId != null) studentData.School__c = schoolId;
    }
    
    /**
     * Create referral form record
     */
    private static Referral_Form__c createReferralFormRecord(Map<String, Object> referralFormDataMap, FormSubmissionResponse response) {
        Referral_Form__c newReferralForm = new Referral_Form__c();
        
        // Remove fields that are not direct fields on Referral_Form__c
        cleanupFormDataForReferralForm(referralFormDataMap);
        
        // Set fields using dynamic field mapping
        Integer fieldsSet = setObjectFields(newReferralForm, referralFormDataMap, 'Referral_Form__c', response);
        System.debug('ReferralForm fields set: ' + fieldsSet);
        
        insert newReferralForm;
        return newReferralForm;
    }
    
    /**
     * Remove lookup fields that are handled separately
     */
    private static void cleanupFormDataForReferralForm(Map<String, Object> referralFormDataMap) {
        List<String> fieldsToRemove = new List<String>{
            'StudentIDNumber__c', 'StudentFirstName__c', 'StudentLastName__c', 
            'DateOfBirth__c', 'Grade__c', 'StudentGender__c',
            'School_Name__c', 'School_District__c', 'School_Address__c'
        };
        
        for (String field : fieldsToRemove) {
            referralFormDataMap.remove(field);
        }
    }
    
    /**
     * Dynamically set object fields from map data
     */
    private static Integer setObjectFields(SObject obj, Map<String, Object> dataMap, String objectType, FormSubmissionResponse response) {
        if (dataMap == null || dataMap.isEmpty()) return 0;
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectType);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        Integer fieldsSetCount = 0;
        List<String> skippedFields = new List<String>();
        
        for (String fieldName : dataMap.keySet()) {
            Object fieldValue = dataMap.get(fieldName);
            
            if (fieldValue == null || String.valueOf(fieldValue).trim() == '') {
                continue;
            }
            
            if (!fieldMap.containsKey(fieldName)) {
                skippedFields.add(fieldName);
                continue;
            }
            
            Schema.SObjectField fieldToken = fieldMap.get(fieldName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            if (!fieldDescribe.isCreateable()) {
                skippedFields.add(fieldName + ' (not creatable)');
                continue;
            }
            
            try {
                Object convertedValue = convertFieldValue(fieldValue, fieldDescribe);
                if (convertedValue != null) {
                    obj.put(fieldName, convertedValue);
                    fieldsSetCount++;
                }
            } catch (Exception e) {
                skippedFields.add(fieldName + ' (conversion error)');
                System.debug('Error setting field ' + fieldName + ': ' + e.getMessage());
            }
        }
        
        if (!skippedFields.isEmpty()) {
            response.warnings.add(objectType + ' fields skipped: ' + String.join(skippedFields, ', '));
        }
        
        return fieldsSetCount;
    }
    
    /**
     * Convert field value based on field type
     */
    private static Object convertFieldValue(Object value, Schema.DescribeFieldResult fieldDescribe) {
        if (value == null) return null;
        
        String stringValue = String.valueOf(value).trim();
        if (String.isBlank(stringValue)) return null;
        
        Schema.DisplayType fieldType = fieldDescribe.getType();
        
        switch on fieldType {
            when STRING, TEXTAREA, PHONE, EMAIL, URL {
                Integer maxLength = fieldDescribe.getLength();
                return maxLength > 0 && stringValue.length() > maxLength 
                    ? stringValue.substring(0, maxLength) 
                    : stringValue;
            }
            when REFERENCE {
                return (stringValue.length() == 15 || stringValue.length() == 18) ? stringValue : null;
            }
            when INTEGER {
                return Integer.valueOf(stringValue);
            }
            when DOUBLE, PERCENT, CURRENCY {
                return Decimal.valueOf(stringValue);
            }
            when BOOLEAN {
                return parseBoolean(stringValue);
            }
            when DATE {
                return Date.valueOf(stringValue);
            }
            when DATETIME {
                return parseDateTime(stringValue);
            }
            when PICKLIST {
                return findPicklistValue(stringValue, fieldDescribe);
            }
            when else {
                return stringValue;
            }
        }
    }
    
    /**
     * Utility methods for field value parsing
     */
    private static String getStringValue(Map<String, Object> dataMap, String fieldName) {
        Object value = dataMap.get(fieldName);
        return (value != null && String.valueOf(value).trim() != '') ? String.valueOf(value).trim() : null;
    }
    
    private static Date getDateValue(Map<String, Object> dataMap, String fieldName) {
        String dateStr = getStringValue(dataMap, fieldName);
        try {
            return dateStr != null ? Date.valueOf(dateStr) : null;
        } catch (Exception e) {
            System.debug('Could not parse date: ' + dateStr);
            return null;
        }
    }
    
    private static Boolean parseBoolean(String value) {
        String lowerValue = value.toLowerCase();
        return lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1' || lowerValue == 'on';
    }
    
    private static Datetime parseDateTime(String value) {
        try {
            return value.contains('T') 
                ? Datetime.valueOf(value.replace('T', ' ').replace('Z', ''))
                : Datetime.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String findPicklistValue(String value, Schema.DescribeFieldResult fieldDescribe) {
        List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
        
        // Exact match first
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.getValue().equalsIgnoreCase(value)) {
                return entry.getValue();
            }
        }
        
        // Partial match second
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.getValue().toLowerCase().contains(value.toLowerCase())) {
                return entry.getValue();
            }
        }
        
        return null;
    }
    
    /**
     * Exception handling methods
     */
    private static void handleReferralFormException(ReferralFormException e, FormSubmissionResponse response) {
        response.success = false;
        response.message = e.getMessage();
        response.errors.add(e.getMessage());
        System.debug('ReferralForm Error: ' + e.getMessage());
    }
    
    private static void handleDmlException(DmlException e, FormSubmissionResponse response) {
        response.success = false;
        response.message = 'Database error occurred';
        for (Integer i = 0; i < e.getNumDml(); i++) {
            String dmlError = 'Record ' + i + ': ' + e.getDmlMessage(i);
            response.errors.add(dmlError);
            System.debug('DML Error: ' + dmlError);
        }
    }
    
    private static void handleGeneralException(Exception e, FormSubmissionResponse response) {
        response.success = false;
        response.message = 'An unexpected error occurred: ' + e.getMessage();
        response.errors.add(e.getMessage());
        System.debug('General Error: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
    }
    
    /**
     * Custom exception class
     */
    public class ReferralFormException extends Exception {}
}