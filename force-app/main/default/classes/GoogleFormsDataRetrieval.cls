public class GoogleFormsDataRetrieval {
    
    private static final String NAMED_CREDENTIAL = 'callout:GoogleFormAPI';
    
    // Required OAuth 2.0 Scopes for Google Forms API:
    // https://www.googleapis.com/auth/forms.responses.readonly
    // https://www.googleapis.com/auth/forms.body.readonly
    
    /**
     * Get all form responses
     * @param formId The Google Form ID
     * @return List of form responses
     */
    public static List<FormResponse> getAllResponses(String formId) {
        // Exact endpoint from Node.js example: forms.forms.responses.list
        String endpoint = NAMED_CREDENTIAL + '/v1/forms/' + formId + '/responses';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        
        System.debug('Making request to: ' + endpoint);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Response Status Code: ' + res.getStatusCode());
        System.debug('Response Status: ' + res.getStatus());
        System.debug('Response Body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            return parseResponses(res.getBody());
        } else {
            throw new CalloutException('Google Forms API Error (' + res.getStatusCode() + '): ' + res.getBody());
        }
    }
    
    /**
     * Test method to check authentication and scopes
     * @param formId The Google Form ID
     * @return Raw API response for debugging
     */
    public static String testConnection(String formId) {
        String endpoint = NAMED_CREDENTIAL + '/v1/forms/' + formId;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        String result = 'Status: ' + res.getStatusCode() + '\n';
        result += 'Headers: ' + res.getHeaderKeys() + '\n';
        result += 'Body: ' + res.getBody();
        
        System.debug(result);
        return result;
    }
    
    /**
     * Get form structure/questions
     * @param formId The Google Form ID
     * @return Form metadata with questions
     */
    public static FormStructure getFormStructure(String formId) {
        String endpoint = NAMED_CREDENTIAL + '/v1/forms/' + formId;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Form Structure Status Code: ' + res.getStatusCode());
        System.debug('Form Structure Response: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            return parseFormStructure(res.getBody());
        } else {
            throw new CalloutException('Google Forms API Error (' + res.getStatusCode() + '): ' + res.getBody());
        }
    }
    
    /**
     * Parse JSON response to FormResponse objects
     */
    private static List<FormResponse> parseResponses(String jsonBody) {
        List<FormResponse> responsesList = new List<FormResponse>();
        
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        List<Object> responses = (List<Object>) data.get('responses');
        
        if (responses != null) {
            for (Object respObj : responses) {
                Map<String, Object> resp = (Map<String, Object>) respObj;
                FormResponse formResp = new FormResponse();
                
                formResp.responseId = (String) resp.get('responseId');
                formResp.createTime = (String) resp.get('createTime');
                formResp.lastSubmittedTime = (String) resp.get('lastSubmittedTime');
                
                // Parse answers
                Map<String, Object> answers = (Map<String, Object>) resp.get('answers');
                if (answers != null) {
                    for (String questionId : answers.keySet()) {
                        Map<String, Object> answerData = (Map<String, Object>) answers.get(questionId);
                        String answerValue = extractAnswerValue(answerData);
                        formResp.answers.put(questionId, answerValue);
                    }
                }
                
                responsesList.add(formResp);
            }
        }
        
        return responsesList;
    }
    
    /**
     * Parse form structure JSON
     */
    private static FormStructure parseFormStructure(String jsonBody) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        FormStructure form = new FormStructure();
        
        form.formId = (String) data.get('formId');
        
        // Get form info
        Map<String, Object> info = (Map<String, Object>) data.get('info');
        if (info != null) {
            form.title = (String) info.get('title');
            form.description = (String) info.get('description');
        }
        
        // Get questions
        List<Object> items = (List<Object>) data.get('items');
        if (items != null) {
            for (Object itemObj : items) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                String itemId = (String) item.get('itemId');
                
                Map<String, Object> title = (Map<String, Object>) item.get('title');
                String questionText = title != null ? (String) title.get('text') : '';
                
                form.questions.put(itemId, questionText);
            }
        }
        
        return form;
    }
    
    /**
     * Extract answer value from answer data
     */
    private static String extractAnswerValue(Map<String, Object> answerData) {
        // Text answers
        Map<String, Object> textAnswers = (Map<String, Object>) answerData.get('textAnswers');
        if (textAnswers != null) {
            List<Object> values = (List<Object>) textAnswers.get('values');
            if (values != null && !values.isEmpty()) {
                Map<String, Object> firstValue = (Map<String, Object>) values[0];
                return (String) firstValue.get('value');
            }
        }
        
        // File upload answers
        Map<String, Object> fileUploadAnswers = (Map<String, Object>) answerData.get('fileUploadAnswers');
        if (fileUploadAnswers != null) {
            List<Object> values = (List<Object>) fileUploadAnswers.get('values');
            if (values != null && !values.isEmpty()) {
                Map<String, Object> firstValue = (Map<String, Object>) values[0];
                return (String) firstValue.get('fileId');
            }
        }
        
        return '';
    }
    
    // Data classes
    public class FormResponse {
        public String responseId;
        public String createTime;
        public String lastSubmittedTime;
        public Map<String, String> answers;
        
        public FormResponse() {
            this.answers = new Map<String, String>();
        }
    }
    
    public class FormStructure {
        public String formId;
        public String title;
        public String description;
        public Map<String, String> questions; // questionId -> question text
        
        public FormStructure() {
            this.questions = new Map<String, String>();
        }
    }
}