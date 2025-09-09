import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import FUNDING_APPLICATION_OBJECT from '@salesforce/schema/Funding_Application__c';
import ENTITY_TYPE_FIELD from '@salesforce/schema/Funding_Application__c.Entity_Type__c';
import STATE_FIELD from '@salesforce/schema/Funding_Application__c.State__c';
import COUNTY_FIELD from '@salesforce/schema/Funding_Application__c.Please_select_the_appropriate_county__c';
import { ValidationUtils } from 'c/validationUtils';

export default class GpsStep1Form extends LightningElement {
    @api formData = {};
    @api errors = {};
    @api uploadedFiles = [];
    @track entityTypeOptions = [];
    @track countyOptions = [];
    @track stateOptions = [];
    @track yesNoOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    @wire(getObjectInfo, { objectApiName: FUNDING_APPLICATION_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ENTITY_TYPE_FIELD })
    entityTypePicklist({ data, error }) {
        if (data) {
            this.entityTypeOptions = data.values;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: STATE_FIELD })
    statePicklist({ data, error }) {
        if (data) {
            this.stateOptions = data.values;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: COUNTY_FIELD })
    countyPicklist({ data, error }) {
        if (data) {
            this.countyOptions = data.values;
        }
    }

    handleInputChange(event) {
        let fieldName = event.target.name;
        let fieldValue = event.target.value;

        if (fieldName.includes('Phone')) {
            fieldValue = ValidationUtils.formatPhoneNumber(fieldValue);
            event.target.value = fieldValue;
        } else if (fieldName.includes('Zip')) {
            fieldValue = ValidationUtils.formatZipCode(fieldValue);
            event.target.value = fieldValue;
        }

        if (fieldName === 'Entity_Type__c' && fieldValue !== 'Other') {
            if(this.formData.Please_Specify_Other_Entity_Type__c) {
                this.formData.Please_Specify_Other_Entity_Type__c = '';
            }
        }

        if (fieldName === 'Any_Potential_Conflict_with_SC_Recovery__c' && fieldValue !== 'Yes') {
            if(this.formData.Identify_the_Board_member_and_Relation__c) {
                this.formData.Identify_the_Board_member_and_Relation__c = '';
            }
        }


        this.dispatchEvent(new CustomEvent('inputchange', {
            detail: { name: fieldName, value: fieldValue }
        }));
    }

    handleFieldBlur(event) {
        const fieldName = event.target.dataset.field;
        const fieldValue = event.target.value;

        this.validateAndSetCustomValidity(event.target, fieldName, fieldValue);
    }

    validateAndSetCustomValidity(element, fieldName, fieldValue) {
        let validation = this.validateField(fieldName, fieldValue);

        if (validation.isValid) {
            element.setCustomValidity('');
        } else {
            element.setCustomValidity(validation.message);
        }

        element.reportValidity();
    }

    validateField(fieldName, fieldValue) {
        let validation = { isValid: true, message: '' };

        switch (fieldName) {
            case 'Program_Manager_Email__c':
            case 'Fiscal_Manager_Email__c':
                validation = ValidationUtils.validateEmail(fieldValue);
                break;
            case 'Program_Manager_Phone_Number__c':
            case 'Fiscal_Manager_Phone_Number__c':
                validation = ValidationUtils.validatePhone(fieldValue);
                break;
            case 'Zip__c':
            case 'OrganizationZip__c':
                validation = ValidationUtils.validateZip(fieldValue);
                break;
            case 'SCEIS_Vendor_Number__c':
                validation = ValidationUtils.validateVendorNumber(fieldValue);
                break;
            case 'City__c':
            case 'OrganizationCity__c':
                validation = ValidationUtils.validateCity(fieldValue);
                break;
            case 'Name_of_Person_Completing_Form__c':
            case 'Program_Manager_Name__c':
                validation = ValidationUtils.validatePersonName(fieldValue, this.getFieldLabel(fieldName));
                break;
            case 'Address_Line_1__c':
            case 'Address_Line_2__c':
                validation = ValidationUtils.validateAddress(fieldValue, this.getFieldLabel(fieldName), fieldName === 'Address_Line_1__c');
                break;
            case 'OrganizationAddressLine1__c':
            case 'OrganizationAddressLine2__c':
                validation = ValidationUtils.validateAddress(fieldValue, this.getFieldLabel(fieldName), fieldName === 'OrganizationAddressLine1__c');
                break;
            case 'Fiscal_Manager_Title__c':
                validation = ValidationUtils.validateText(fieldValue, this.getFieldLabel(fieldName), true);
                break;
            case 'Identify_the_Board_member_and_Relation__c':
                validation = ValidationUtils.validateTextarea(fieldValue, this.getFieldLabel(fieldName), 255, false);
                break;
            case 'Please_Specify_Other_Entity_Type__c':
                validation = ValidationUtils.validateText(fieldValue, this.getFieldLabel(fieldName), this.formData.Entity_Type__c === 'Other');
                break;
            case 'Entity_Type__c':
            case 'OrganizationState__c':
                validation = ValidationUtils.validateRequired(fieldValue, this.getFieldLabel(fieldName));
                break;
        }

        return validation;
    }

    @api
    validateStep() {
        console.log('Validating Step');

        const allValid = this.validateAllFields();

        if (!allValid) {
            this.showToast('Error', 'Please correct the errors below before continuing', 'error');
            this.scrollToFirstError();
        }

        return allValid;
    }

    validateAllFields() {
        const allInputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        let allValid = true;

        allInputs.forEach(input => {
            const fieldName = input.dataset.field;
            const fieldValue = input.value;

            if (fieldName) {
                const validation = this.validateField(fieldName, fieldValue);
                // const conditionFields = this.validateAndSetCustomValidity();

                if (!validation.isValid) {
                    input.setCustomValidity(validation.message);
                    allValid = false;
                } else {
                    input.setCustomValidity('');
                }

                input.reportValidity();
            }
        });

        if (allValid) {
            allValid = this.validateConditionalFields();
        }

        console.log(allValid);
        return allValid;
    }

    scrollToFirstError() {
        const firstErrorField = this.template.querySelector('lightning-input[aria-invalid="true"], lightning-combobox[aria-invalid="true"], lightning-textarea[aria-invalid="true"]');
        if (firstErrorField) {
            firstErrorField.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            });
            firstErrorField.focus();
        }
    }

    validateConditionalFields() {
        let isValid = true;
        console.log('Validating conditional fields');

        if (this.formData.Entity_Type__c === 'Other') {
            if (!this.formData.Please_Specify_Other_Entity_Type__c) {
                isValid = false;
            } else {
                const otherEntityField = this.template.querySelector('[data-field="Please_Specify_Other_Entity_Type__c"]');
                if (otherEntityField) {
                    const validation = this.validateField('Please_Specify_Other_Entity_Type__c', this.formData.Please_Specify_Other_Entity_Type__c);
                    if (!validation.isValid) {
                        otherEntityField.setCustomValidity(validation.message);
                        otherEntityField.reportValidity();
                        isValid = false;
                    } else {
                        otherEntityField.setCustomValidity('');
                        otherEntityField.reportValidity();
                    }
                }
            }
        }

        console.log('Entity Type Other validation result:', isValid);

        if (this.formData.Any_Potential_Conflict_with_SC_Recovery__c === 'Yes') {
            if (!this.formData.Identify_the_Board_member_and_Relation__c) {
                isValid = false;
            } else {
                const conflictField = this.template.querySelector('[data-field="Identify_the_Board_member_and_Relation__c"]');
                if (conflictField) {
                    const validation = this.validateField('Identify_the_Board_member_and_Relation__c', this.formData.Identify_the_Board_member_and_Relation__c);
                    if (!validation.isValid) {
                        conflictField.setCustomValidity(validation.message);
                        conflictField.reportValidity();
                        isValid = false;
                    } else {
                        conflictField.setCustomValidity('');
                        conflictField.reportValidity();
                    }
                }
            }
        }

        console.log('Conditional fields validation result:', isValid);

        return isValid;
    }

    get isEntityTypeOther() {
        return this.formData.Entity_Type__c === 'Other';
    }

    get isCollaboratingOtherGPS() {
        return this.formData.Collaborating_with_Other_GPS_Entity__c === 'Yes';
    }

    get isPotentialConflictYes() {
        return this.formData.Any_Potential_Conflict_with_SC_Recovery__c === 'Yes';
    }

    getFieldLabel(fieldName) {
        const fieldLabels = {
            'SCEIS_Vendor_Number__c': 'SCEIS Vendor Number',
            'Entity_Type__c': 'Entity Type',
            'Please_Specify_Other_Entity_Type__c': 'Other Entity Type',
            'Name_of_Person_Completing_Form__c': 'Name of Person Completing Form',
            'Collaborating_with_Other_GPS_Entity__c': 'Collaborating with Other GPS',
            'Please_select_the_appropriate_county__c': 'Appropriate County',
            'Is_Entity_an_SC_Bellwether_Plaintiff__c': 'SC Bellwether Plaintiff',
            'Was_the_requesting_Entity_a_litigating_s__c': 'Litigating Subdivision',
            'Any_Potential_Conflict_with_SC_Recovery__c': 'Potential Conflict',
            'Identify_the_Board_member_and_Relation__c': 'Board Member and Relationship',
            'Address_Line_1__c': 'Payment Address Line 1',
            'Address_Line_2__c': 'Payment Address Line 2',
            'City__c': 'Payment City',
            'State__c': 'Payment State',
            'Zip__c': 'Payment ZIP Code',
            'OrganizationAddressLine1__c': 'Organization Address Line 1',
            'OrganizationAddressLine2__c': 'Organization Address Line 2',
            'OrganizationCity__c': 'Organization City',
            'OrganizationState__c': 'Organization State',
            'OrganizationZip__c': 'Organization ZIP Code',
            'Program_Manager_Name__c': 'Program Manager Name',
            'Program_Manager_Email__c': 'Program Manager Email',
            'Program_Manager_Phone_Number__c': 'Program Manager Phone',
            'Fiscal_Manager_Title__c': 'Fiscal Manager Title',
            'Fiscal_Manager_Email__c': 'Fiscal Manager Email',
            'Fiscal_Manager_Phone_Number__c': 'Fiscal Manager Phone',
        };
        return fieldLabels[fieldName] || fieldName;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant || 'info',
            })
        );
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFiles = [...this.uploadedFiles, ...uploadedFiles];
        console.log('Files uploaded:', JSON.stringify(this.uploadedFiles, null, 2));
        this.dispatchEvent(new CustomEvent('filesuploaded', { detail: this.uploadedFiles }));
    }

    get uploadedFilesLen() {
        return this.uploadedFiles.length === 0 ? false : true;
    }

    handleDeleteFile(event) {
        console.log('Delete file event triggered:', JSON.stringify(event.target));
        console.log('Event target dataset:', event.target.dataset);
        console.log('Event target dataset id:', JSON.stringify(event.detail));


        console.log('Deleting file with ID:', event.target.dataset.id);

        const fileId = event.target.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== fileId);
        console.log('File deleted:', fileId, 'Remaining files:', JSON.stringify(this.uploadedFiles));

        this.dispatchEvent(new CustomEvent('filedeleted', { detail: fileId }));
    }
}