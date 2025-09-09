import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Updated import to use the new method that handles duplicate deletion
import createReferralFormAndDeleteDuplicate from '@salesforce/apex/ReferralFormService.createReferralFormAndDeleteDuplicate';

// Use schema imports for robustness and to prevent typos
import DUPLICATE_REFERRAL_OBJECT from '@salesforce/schema/Duplicate_Referral__c';
import JSON_DATA_FIELD from '@salesforce/schema/Duplicate_Referral__c.JSON_Data__c';
import REFERRAL_FORM_LOOKUP_FIELD from '@salesforce/schema/Duplicate_Referral__c.Referral_Form__c';

// Define fields for the duplicate record using imports for better maintainability
import REFERRAL_TYPE_FIELD from '@salesforce/schema/Referral_Form__c.What_type_of_referral_is_this__c';
import SCHOOL_NAME_FIELD from '@salesforce/schema/Referral_Form__c.School_Name__c';
import FIRST_NAME_FIELD from '@salesforce/schema/Referral_Form__c.ParentGuardianAdultFirstName__c';
import LAST_NAME_FIELD from '@salesforce/schema/Referral_Form__c.ParentGuardianAdultLastName__c';
import PHONE_FIELD from '@salesforce/schema/Referral_Form__c.ParentGuardianAdultPhoneNumber__c';
import EMAIL_FIELD from '@salesforce/schema/Referral_Form__c.ParentGuardianAdultEmail__c';
import REASON_FIELD from '@salesforce/schema/Referral_Form__c.ReasonForReferral__c';
import OTHER_REASON_FIELD from '@salesforce/schema/Referral_Form__c.OtherReasonForReferral__c';
import DETAILED_REASON_FIELD from '@salesforce/schema/Referral_Form__c.KindlyDetailReasonForReferral__c';
import SOURCE_NAME_FIELD from '@salesforce/schema/Referral_Form__c.NameOfReferralSource__c';
import SOURCE_PHONE_FIELD from '@salesforce/schema/Referral_Form__c.ReferralSourcePhoneNumber__c';
import SOURCE_EMAIL_FIELD from '@salesforce/schema/Referral_Form__c.ReferralSourceEmail__c';
import STAFF_ROLE_FIELD from '@salesforce/schema/Referral_Form__c.SchoolStaffMemberRole__c';
import ID_FIELD from '@salesforce/schema/Referral_Form__c.Id';
import CREATED_DATE_FIELD from '@salesforce/schema/Referral_Form__c.CreatedDate';

const REFERRAL_FIELDS = [
    REFERRAL_TYPE_FIELD, SCHOOL_NAME_FIELD, FIRST_NAME_FIELD, LAST_NAME_FIELD,
    PHONE_FIELD, EMAIL_FIELD, REASON_FIELD, OTHER_REASON_FIELD, DETAILED_REASON_FIELD,
    SOURCE_NAME_FIELD, SOURCE_PHONE_FIELD, SOURCE_EMAIL_FIELD, STAFF_ROLE_FIELD,
    ID_FIELD, CREATED_DATE_FIELD
];

const DUPLICATE_CONTAINER_FIELDS = [JSON_DATA_FIELD, REFERRAL_FORM_LOOKUP_FIELD];

export default class ReferralDuplicateViewer extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId; // This is the ID of the Duplicate_Referral__c record

    // Private reactive properties
    currentData;
    duplicateData;
    isLoading = true;
    error;

    // Internal state
    duplicateRecordId;
    rawJsonData; // Store raw JSON for API call

    // Wire service to get the container record with JSON data and the lookup to the actual duplicate
    @wire(getRecord, { recordId: '$recordId', fields: DUPLICATE_CONTAINER_FIELDS })
    wiredDuplicateContainer({ error, data }) {
        if (data) {
            try {
                this.duplicateRecordId = data.fields[REFERRAL_FORM_LOOKUP_FIELD.fieldApiName]?.value;
                const currentFormData = data.fields[JSON_DATA_FIELD.fieldApiName]?.value;

                if (currentFormData) {
                    // Store raw JSON data for the API call
                    this.rawJsonData = currentFormData;
                    
                    const parsedData = JSON.parse(currentFormData);
                    const dataForTransform = parsedData.referralFormData || parsedData;

                    // --- START: NEW NORMALIZATION STEP ---
                    // Map the keys from your JSON to the Salesforce API Name keys.
                    // You MUST update the keys on the right (e.g., dataForTransform.School_Name)
                    // to match what you see in your console.log output.
                    const normalizedData = {
                        [SCHOOL_NAME_FIELD.fieldApiName]: dataForTransform.School_Name__c || dataForTransform.School_Name,
                        [REFERRAL_TYPE_FIELD.fieldApiName]: dataForTransform.What_type_of_referral_is_this__c,
                        [FIRST_NAME_FIELD.fieldApiName]: dataForTransform.ParentGuardianAdultFirstName__c,
                        [LAST_NAME_FIELD.fieldApiName]: dataForTransform.ParentGuardianAdultLastName__c,
                        [PHONE_FIELD.fieldApiName]: dataForTransform.ParentGuardianAdultPhoneNumber__c,
                        [EMAIL_FIELD.fieldApiName]: dataForTransform.ParentGuardianAdultEmail__c,
                        [REASON_FIELD.fieldApiName]: dataForTransform.ReasonForReferral__c,
                        [OTHER_REASON_FIELD.fieldApiName]: dataForTransform.OtherReasonForReferral__c,
                        [DETAILED_REASON_FIELD.fieldApiName]: dataForTransform.KindlyDetailReasonForReferral__c,
                        [SOURCE_NAME_FIELD.fieldApiName]: dataForTransform.NameOfReferralSource__c,
                        [SOURCE_PHONE_FIELD.fieldApiName]: dataForTransform.ReferralSourcePhoneNumber__c,
                        [SOURCE_EMAIL_FIELD.fieldApiName]: dataForTransform.ReferralSourceEmail__c,
                        [STAFF_ROLE_FIELD.fieldApiName]: dataForTransform.SchoolStaffMemberRole__c
                    };
                    // --- END: NEW NORMALIZATION STEP ---

                    // Now, pass the perfectly structured object to the transform function.
                    this.currentData = this.transformReferralData(normalizedData, false);

                    // For debugging, you can check the transformed data
                    console.log('Transformed Data:', JSON.stringify(this.currentData, null, 2));

                } else {
                    throw new Error('JSON data is missing from the duplicate record.');
                }
            } catch (e) {
                this.handleError('Error processing new record data: ' + e.message);
            }
        } else if (error) {
            this.handleError('Could not load duplicate container.', error);
        }
    }

    // Wire service to get the actual duplicate record's data
    @wire(getRecord, { recordId: '$duplicateRecordId', fields: REFERRAL_FIELDS })
    wiredDuplicateRecord({ error, data }) {
        if (data) {
            this.duplicateData = this.transformReferralData(data, true);
        } else if (error) {
            this.handleError('Could not load existing duplicate record.', error);
        }
        // Data loading is complete (or has failed), so stop the spinner
        this.isLoading = false;
    }

    // Centralized data transformation to avoid code repetition (DRY principle)
    transformReferralData(data, isLdsFormat) {
        const getValue = (field) => {
            // For LDS data from a Salesforce record, access nested 'value' property
            if (isLdsFormat) {
                return data.fields[field.fieldApiName]?.value;
            }
            // For our normalized JSON data, access the property directly
            return data[field.fieldApiName];
        };

        const firstName = getValue(FIRST_NAME_FIELD) || '';
        const lastName = getValue(LAST_NAME_FIELD) || '';

        // The rest of this function remains the same...
        return {
            referralType: getValue(REFERRAL_TYPE_FIELD) || 'N/A',
            schoolName: getValue(SCHOOL_NAME_FIELD) || 'N/A',
            fullName: `${firstName} ${lastName}`.trim() || 'N/A',
            phoneNumber: getValue(PHONE_FIELD) || 'N/A',
            email: getValue(EMAIL_FIELD) || 'N/A',
            reasonForReferral: getValue(REASON_FIELD) || 'N/A',
            otherReason: getValue(OTHER_REASON_FIELD) || 'N/A',
            detailedReason: getValue(DETAILED_REASON_FIELD) || 'N/A',
            referralSource: getValue(SOURCE_NAME_FIELD) || 'N/A',
            sourcePhone: getValue(SOURCE_PHONE_FIELD) || 'N/A',
            sourceEmail: getValue(SOURCE_EMAIL_FIELD) || 'N/A',
            staffRole: getValue(STAFF_ROLE_FIELD) || 'N/A',
            recordId: isLdsFormat ? data.id : 'New Record',
            createdDate: isLdsFormat ? this.formatDate(getValue(CREATED_DATE_FIELD)) : 'Now'
        };
    }

    // Getter for the list of fields to display
    get fieldLabels() {
        return [
            { key: 'referralType', label: 'Referral Type' },
            { key: 'schoolName', label: 'School Name' },
            { key: 'fullName', label: 'Full Name' },
            { key: 'phoneNumber', label: 'Phone Number' },
            { key: 'email', label: 'Email' },
            { key: 'reasonForReferral', label: 'Reason for Referral' },
            { key: 'detailedReason', label: 'Detailed Reason' },
            { key: 'referralSource', label: 'Referral Source' },
            { key: 'createdDate', label: 'Created Date' }
        ];
    }

    // Precompute rows for the template to keep it clean
    get currentFieldRows() {
        if (!this.currentData) return [];
        return this.fieldLabels.map(field => ({
            ...field,
            value: this.currentData[field.key],
            // Dynamically set class for highlighting
            valueClass: `slds-item__detail slds-text-body_regular ${this.isDifferent(field.key) ? 'highlight-different' : ''}`
        }));
    }

    get duplicateFieldRows() {
        if (!this.duplicateData) return [];
        return this.fieldLabels.map(field => ({
            ...field,
            value: this.duplicateData[field.key],
            // Dynamically set class for highlighting
            valueClass: `slds-item__detail slds-text-body_regular ${this.isDifferent(field.key) ? 'highlight-different' : ''}`
        }));
    }

    // Helper to compare values - Updated to ignore spaces and only highlight when different
    isDifferent(key) {
        // Ensure both objects are loaded before comparing
        if (!this.currentData || !this.duplicateData) {
            return false;
        }
        
        // Get values from both records
        const currentValue = this.currentData[key];
        const duplicateValue = this.duplicateData[key];
        
        // Handle null/undefined cases
        if (!currentValue && !duplicateValue) {
            return false; // Both are empty/null, so they're the same
        }
        
        if (!currentValue || !duplicateValue) {
            return true; // One is empty and other is not, so they're different
        }
        
        // Convert both values to strings and remove all spaces for comparison
        const normalizedCurrent = String(currentValue).replace(/\s+/g, '').toLowerCase();
        const normalizedDuplicate = String(duplicateValue).replace(/\s+/g, '').toLowerCase();
        
        // Return true only if they are actually different
        return normalizedCurrent !== normalizedDuplicate;
    }

    // ### EVENT HANDLERS ###

    handleViewRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.duplicateRecordId,
                actionName: 'view',
            },
        });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // Updated method to create new record and automatically delete duplicate
    handleContinueNew() {
        this.isLoading = true;
        
        console.log('Starting createReferralFormAndDeleteDuplicate with data:', this.rawJsonData);
        console.log('Duplicate record ID to delete:', this.recordId);
        
        // Parse the JSON data to modify it
        let parsedData;
        try {
            parsedData = JSON.parse(this.rawJsonData);
        } catch (e) {
            this.handleError('Error parsing JSON data: ' + e.message);
            return;
        }
        
        // Add a flag to bypass duplicate detection
        parsedData.bypassDuplicateCheck = true;
        
        // Convert back to JSON
        const modifiedJsonData = JSON.stringify(parsedData);
        
        // Use the new method that creates record and deletes duplicate
        createReferralFormAndDeleteDuplicate({ 
            jsonData: modifiedJsonData, 
            duplicateRecordId: this.recordId 
        })
            .then(result => {
                console.log('Raw API Response:', result);
                console.log('API Response Type:', typeof result);
                console.log('API Response Keys:', Object.keys(result || {}));
                console.log('API Response JSON:', JSON.stringify(result, null, 2));
                
                // Check if result is null, undefined, or empty
                if (!result) {
                    throw new Error('API returned null or undefined response');
                }
                
                // Check if result is an empty object
                if (typeof result === 'object' && Object.keys(result).length === 0) {
                    throw new Error('API returned empty object response. Check Salesforce Debug Logs for server-side errors.');
                }
                
                // Check for success property
                if (result.hasOwnProperty('success')) {
                    if (result.success) {
                        // Create success message based on what was accomplished
                        let successMessage = result.message || 'Referral form created successfully';
                        
                        // Add information about duplicate deletion
                        if (result.duplicateDeleted) {
                            successMessage += ' The duplicate record has been automatically removed.';
                        }
                        
                        this.showToast('Success', successMessage, 'success');
                        
                        // Dispatch event with all the details
                        this.dispatchEvent(new CustomEvent('newrecordcreated', {
                            detail: { 
                                newRecordId: result.referralFormId,
                                studentDataId: result.studentDataId,
                                schoolId: result.schoolId,
                                processingTime: result.processingTime,
                                duplicateDeleted: result.duplicateDeleted,
                                deletedDuplicateId: result.deletedDuplicateId
                            }
                        }));
                    } else {
                        // Handle unsuccessful response
                        const errorMessage = result.errors && result.errors.length > 0 
                            ? result.errors.join(', ') 
                            : result.message || 'Unknown error occurred during processing';
                        
                        this.showToast('Error', errorMessage, 'error');
                        
                        // Log warnings if any
                        if (result.warnings && result.warnings.length > 0) {
                            console.warn('Processing Warnings:', result.warnings);
                            
                            // Show warnings in toast if they contain important info about duplicate deletion
                            const duplicateWarnings = result.warnings.filter(warning => 
                                warning.toLowerCase().includes('duplicate') && 
                                warning.toLowerCase().includes('delete')
                            );
                            
                            if (duplicateWarnings.length > 0) {
                                this.showToast('Warning', duplicateWarnings.join(' '), 'warning');
                            }
                        }
                    }
                } else {
                    // Result doesn't have expected structure
                    console.error('Unexpected response structure:', result);
                    throw new Error('API response missing expected properties. Check Salesforce Debug Logs for server-side errors.');
                }
            })
            .catch(error => {
                console.error('Apex method error details:', {
                    message: error.message,
                    body: error.body,
                    stack: error.stack,
                    name: error.name
                });
                
                let errorMessage = 'Error creating new referral record: ';
                
                // Handle different types of errors
                if (error.body) {
                    if (error.body.message) {
                        errorMessage += error.body.message;
                    } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        errorMessage += error.body.pageErrors[0].message;
                    } else if (error.body.fieldErrors) {
                        const fieldErrorMessages = [];
                        Object.keys(error.body.fieldErrors).forEach(field => {
                            error.body.fieldErrors[field].forEach(fieldError => {
                                fieldErrorMessages.push(`${field}: ${fieldError.message}`);
                            });
                        });
                        errorMessage += fieldErrorMessages.join(', ');
                    } else {
                        errorMessage += JSON.stringify(error.body);
                    }
                } else if (error.message) {
                    errorMessage += error.message;
                } else {
                    errorMessage += 'Unknown error occurred. Check browser console and Salesforce debug logs.';
                }
                
                this.handleError(errorMessage);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleUpdateExisting() {
        this.dispatchEvent(new CustomEvent('updateexisting', {
            detail: {
                recordIdToUpdate: this.duplicateRecordId,
                newData: this.currentData,
                rawJsonData: this.rawJsonData // Include raw JSON in case parent needs it
            }
        }));
    }

    // ### UTILITY FUNCTIONS ###

    formatDate(dateString) {
        if (!dateString) return 'N/A';
        const options = { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
        return new Date(dateString).toLocaleDateString('en-US', options);
    }

    handleError(message, error) {
        this.error = message;
        console.error(message, error);
        this.showToast('Error', message, 'error');
        this.isLoading = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}