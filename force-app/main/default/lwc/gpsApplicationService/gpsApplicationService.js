import createFundingApplication from '@salesforce/apex/GPSApplicationController.createFundingApplication';
import updateFundingApplication from '@salesforce/apex/GPSApplicationController.updateFundingApplication';
import getFundingApplication from '@salesforce/apex/GPSApplicationController.getFundingApplication';
import getCurrentUser from '@salesforce/apex/GPSApplicationController.getCurrentUser';

/**
 * Service class for handling GPS Application data operations
 * Centralizes all API calls and data transformations
 */
export class GPSApplicationService {
    
    /**
     * Get current user information
     * @returns {Promise<Object>} User data
     */
    async getCurrentUser() {
        try {
            return await getCurrentUser();
        } catch (error) {
            throw this.enhanceError(error, 'Failed to get current user');
        }
    }

    /**
     * Create a new funding application
     * @param {Object} applicationData - Application data to create
     * @returns {Promise<String>} New application ID
     */
    async createApplication(applicationData) {
        try {
            const sanitizedData = this.sanitizeApplicationData(applicationData);
            return await createFundingApplication({ applicationData: sanitizedData });
        } catch (error) {
            throw this.enhanceError(error, 'Failed to create application');
        }
    }

    /**
     * Update existing funding application
     * @param {String} applicationId - Application ID to update
     * @param {Object} applicationData - Updated application data
     * @returns {Promise<void>}
     */
    async updateApplication(applicationId, applicationData) {
        try {
            const sanitizedData = this.sanitizeApplicationData(applicationData);
            return await updateFundingApplication({ 
                applicationId, 
                applicationData: sanitizedData 
            });
        } catch (error) {
            throw this.enhanceError(error, 'Failed to update application');
        }
    }

    /**
     * Get existing funding application
     * @param {String} applicationId - Application ID to retrieve
     * @returns {Promise<Object>} Application data
     */
    async getApplication(applicationId) {
        try {
            return await getFundingApplication({ applicationId });
        } catch (error) {
            throw this.enhanceError(error, 'Failed to load application');
        }
    }

    /**
     * Initialize new application with default values
     * @param {Object} userData - Current user data
     * @returns {Object} Initial application data
     */
    initializeNewApplication(userData) {
        return {
            Name_of_Person_Completing_Form__c: userData?.Name || '',
            Date__c: new Date().toISOString().split('T')[0],
            Application_Status__c: 'Draft'
        };
    }

    /**
     * Prepare application data for submission
     * @param {Object} formData - Form data
     * @param {Array} uploadedFiles - Uploaded files
     * @param {Array} partners - Partners data
     * @param {String} status - Application status
     * @returns {Object} Prepared application data
     */
    prepareSubmissionData(formData, uploadedFiles, partners, status = 'Submitted') {
        return {
            ...formData,
            Application_Status__c: status,
            UploadedFiles: uploadedFiles || [],
            Partners: partners || []
        };
    }

    /**
     * Sanitize application data before sending to server
     * @param {Object} data - Raw application data
     * @returns {Object} Sanitized data
     */
    sanitizeApplicationData(data) {
        // Remove any null or undefined values
        const sanitized = {};
        Object.keys(data).forEach(key => {
            if (data[key] !== null && data[key] !== undefined) {
                sanitized[key] = data[key];
            }
        });
        return sanitized;
    }

    /**
     * Enhance error with additional context
     * @param {Error} error - Original error
     * @param {String} context - Error context
     * @returns {Error} Enhanced error
     */
    enhanceError(error, context) {
        const enhancedError = new Error(`${context}: ${error.body?.message || error.message || 'Unknown error'}`);
        enhancedError.originalError = error;
        enhancedError.context = context;
        return enhancedError;
    }

    /**
     * Extract application ID from URL parameters
     * @returns {String|null} Application ID or null
     */
    getApplicationIdFromUrl() {
        return new URLSearchParams(window.location.search).get('id') || null;
    }

    /**
     * Validate application data structure
     * @param {Object} data - Application data to validate
     * @returns {Object} Validation result
     */
    validateApplicationStructure(data) {
        const errors = [];
        
        if (!data) {
            errors.push('Application data is required');
            return { isValid: false, errors };
        }

        // Add specific validation rules as needed
        if (!data.Name_of_Person_Completing_Form__c) {
            errors.push('Person completing form name is required');
        }

        return {
            isValid: errors.length === 0,
            errors
        };
    }
}