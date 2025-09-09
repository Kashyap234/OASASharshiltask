import { LightningElement, track, api } from 'lwc';

export default class GPSformStepTwo extends LightningElement {
    @track partnerData = {
        Id: null,
        RecordId: null,
        Partner_Name__c: '',
        Describe_Current_Budget_and_Funding_Sour__c: '',
        Geographic_Area_Population_Poverty__c: '',
        Outline_Existing_Efforts_and_New_Expansi__c: ''
    };

    @api partnerNumber = 1;
    @api isEditing = false;
    @api stepTitle = 'Add Partner Information';
    
    @track isInitializing = false;

    connectedCallback() {
        this.partnerData.Id = this.partnerNumber;
        console.log('Step Two connected with partner number:', this.partnerNumber);
    }

    @api
    getPartnerData() {
        return { 
            ...this.partnerData,
            Id: this.partnerNumber 
        };
    }

    @api
    setPartnerData(data) {
        if (data) {
            this.isInitializing = true;
            this.partnerData = { 
                ...this.partnerData,
                ...data,
                Id: this.partnerNumber
            };
            
            console.log('Partner data set in step two:', this.partnerData);
            
            setTimeout(() => {
                this.updateFormFields();
                this.isInitializing = false;
                
                this.validateAndNotifyParent();
            }, 50);
        }
    }

    updateFormFields() {
        this.template.querySelectorAll('lightning-input, lightning-textarea').forEach(input => {
            if (input.name && this.partnerData[input.name] !== undefined) {
                input.value = this.partnerData[input.name];
            }
        });
    }

    @api
    validatePartner() {
        const isValid = this.partnerData.Partner_Name__c && 
                       this.partnerData.Partner_Name__c.trim() !== '';
        
        if (!isValid) {
            const partnerNameInput = this.template.querySelector('lightning-input[name="Partner_Name__c"]');
            if (partnerNameInput) {
                partnerNameInput.setCustomValidity('Partner name is required');
                partnerNameInput.reportValidity();
            }
        } else {
            const partnerNameInput = this.template.querySelector('lightning-input[name="Partner_Name__c"]');
            if (partnerNameInput) {
                partnerNameInput.setCustomValidity('');
                partnerNameInput.reportValidity();
            }
        }
        
        return isValid;
    }

    @api
    resetForm() {
        this.partnerData = {
            Id: this.partnerNumber,
            Partner_Name__c: '',
            Describe_Current_Budget_and_Funding_Sour__c: '',
            Geographic_Area_Population_Poverty__c: '',
            Outline_Existing_Efforts_and_New_Expansi__c: ''
        };
        
        setTimeout(() => {
            this.template.querySelectorAll('lightning-input, lightning-textarea').forEach(input => {
                input.value = '';
                input.setCustomValidity('');
                input.reportValidity();
            });
        }, 50);
        
        this.validateAndNotifyParent();
    }

    get isFormValid() {
        return this.partnerData.Partner_Name__c && 
               this.partnerData.Partner_Name__c.trim() !== '';
    }

    get isFormInvalid() {
        return !this.isFormValid;
    }

    get cardTitle() {
        return this.stepTitle || 'Partner Information';
    }

    get partnerNumberDisplay() {
        return this.isEditing ? 
            `Editing Partner #${this.partnerNumber}` : 
            `Partner #${this.partnerNumber}`;
    }

    validateAndNotifyParent() {
        const isValid = this.isFormValid;
        
        this.dispatchEvent(new CustomEvent('partnerchange', {
            detail: {
                partnerData: this.getPartnerData(),
                isValid: isValid
            }
        }));
        
        return isValid;
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;

        this.partnerData = {
            ...this.partnerData,
            [fieldName]: value
        };

        console.log('Partner data changed:', fieldName, value);
        console.log('Current partner data:', this.partnerData);
        
        if (!this.isInitializing) {
            this.validateAndNotifyParent();
        }
    }

    renderedCallback() {
        if (this.partnerData && Object.keys(this.partnerData).length > 0 && !this.isInitializing) {
            this.updateFormFields();
        }
    }
}