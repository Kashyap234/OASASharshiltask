import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createFundingApplication from '@salesforce/apex/GPSApplicationController.createFundingApplication';
import updateFundingApplication from '@salesforce/apex/GPSApplicationController.updateFundingApplication';
import getFundingApplication from '@salesforce/apex/GPSApplicationController.getFundingApplication';
import getCurrentUser from '@salesforce/apex/GPSApplicationController.getCurrentUser';
import { NavigationMixin } from 'lightning/navigation';

export default class GPSApplicationForm extends  NavigationMixin(LightningElement) {
    applicationId;
    formData = {};
    isLoading = false;
    currentStep = 1;
    totalSteps = 4;
    errors = {};
    uploadedFiles = [];
    isStepValid = false;
    partners = [];
    currentPartnerData = {};
    isCurrentPartnerValid = false;
    currentPartnerIndex = 0;
    isEditingExistingPartner = false;
    activePartnerData = {};
    isWorkingWithPartner = false;
    strategiesData = {};
    currentStrategiesPartnerId = null;

    isExistingApplication = false;
    originalApplicationStatus = null;
    hasDataLoaded = false;
    isPreviewOpen = false;

    connectedCallback() {
        this.initializeForm();
    }

    async initializeForm() {
        this.applicationId = new URLSearchParams(window.location.search).get('id') || null;

        if (this.applicationId === null) {
            this.applicationId = new URLSearchParams(window.location.search).get('Id') || null;
        }

        this.isExistingApplication = !!this.applicationId;

        console.log(`Initializing form with application ID: ${this.applicationId}`);


        try {
            const user = await getCurrentUser();

            if (this.isExistingApplication) {
                await this.loadExistingApplication();
            } else {
                this.formData = {
                    Name_of_Person_Completing_Form__c: user.Name,
                    Date__c: new Date().toISOString().split('T')[0],
                    Application_Status__c: 'Draft'
                };
            }

            this.hasDataLoaded = true;
        } catch (error) {
            this.showToast('Error', 'Failed to load application information', 'error');
            console.error('Error initializing form:', error);
        }
    }

    async loadExistingApplication() {
        console.log(`Loading existing application with ID: ${this.applicationId}`);

        try {
            this.isLoading = true;
            const applicationData = await getFundingApplication({ applicationId: this.applicationId });

            this.formData = { ...applicationData };
            this.originalApplicationStatus = applicationData.Application_Status__c;

            console.log(`Loaded application data: ${JSON.stringify(this.formData, null, 2)}`);

            if (applicationData.UploadedFiles && Array.isArray(applicationData.UploadedFiles)) {
                this.uploadedFiles = [...applicationData.UploadedFiles];
            }

            if (applicationData.Partners && Array.isArray(applicationData.Partners)) {
                this.partners = applicationData.Partners.map((partner, index) => ({
                    ...partner,
                    Id: index + 1
                }));

                if (this.partners.length > 0) {
                    this.activePartnerData = { ...this.partners[0] };
                    this.strategiesData = this.partners[0].strategiesData || {};
                    this.currentStrategiesPartnerId = this.partners[0].Id;
                    this.isWorkingWithPartner = true;
                }
            }

            setTimeout(() => {
                this.loadDataIntoComponents();
            }, 100);

            this.showToast('Success', 'Application data loaded successfully', 'success');

        } catch (error) {
            console.error('Error loading application:', error);
            this.showToast('Error', `Failed to load application: ${error.body?.message || 'Unknown error'}`, 'error');
            this.isExistingApplication = false;
            this.applicationId = null;
            await this.initializeNewApplication();
        } finally {
            this.isLoading = false;
        }
    }

    async initializeNewApplication() {
        try {
            const user = await getCurrentUser();
            this.formData = {
                Name_of_Person_Completing_Form__c: user.Name,
                Date__c: new Date().toISOString().split('T')[0],
                Application_Status__c: 'Draft'
            };
        } catch (error) {
            console.error('Error initializing new application:', error);
        }
    }

    loadDataIntoComponents() {
        // Load data into Step 1 component
        const stepOneComponent = this.template.querySelector('c-g-p-sform-step-one');
        if (stepOneComponent && stepOneComponent.loadFormData) {
            stepOneComponent.loadFormData(this.formData);
        }

        const fileUploadComponent = this.template.querySelector('lightning-file-upload') ||
            this.template.querySelector('[data-id="file-upload"]');
        if (fileUploadComponent && this.uploadedFiles.length > 0) {
            this.handleExistingFiles();
        }
    }

    handleExistingFiles() {
        const fileEvent = new CustomEvent('loadexistingfiles', {
            detail: { files: this.uploadedFiles }
        });
        this.dispatchEvent(fileEvent);
    }

    handleBudgetInputChange(event) {
        const { name, value, type } = event.detail;
        let parsedValue = value;

        if (type === 'number') {
            parsedValue = value ? parseFloat(value) : null;
        }

        this.formData = {
            ...this.formData,
            [name]: parsedValue
        };
    }

    get totalAmountRequested() {
        const total = parseFloat(this.formData.Total_Project_Budget__c) || 0;
        const minusCarry = parseFloat(this.formData.Minus_Estimated_Carry_Forward_Amount__c) || 0;
        const minusInterest = parseFloat(this.formData.Minus_Estimated_Interest_Earned__c) || 0;
        return (total - minusCarry - minusInterest).toFixed(2);
    }

    handleInputChange(event) {
        const { name, value } = event.detail;
        this.formData = { ...this.formData, [name]: value };
    }

    handleUploadFinished(event) {
        console.log('Files uploaded:', JSON.stringify(event.detail));

        this.uploadedFiles = [...this.uploadedFiles, ...event.detail];
    }

    handleDeleteFile(event) {
        const fileId = event.detail;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== fileId);
        console.log('File deleted: ', JSON.stringify(event.detail), 'Remaining files:', JSON.stringify(this.uploadedFiles));
    }

    handleValidate(event) {
        const { isValid, errors } = event.detail;
        this.isStepValid = isValid;
        this.errors = { ...this.errors, ...errors };
    }

    handlePartnerChange(event) {
        const { partnerData, isValid } = event.detail;
        this.currentPartnerData = { ...partnerData };
        this.isCurrentPartnerValid = isValid;
        this.activePartnerData = { ...partnerData };
    }

    handleStrategiesDataChange(event) {
        if (this.activePartnerData && this.activePartnerData.Id) {
            const partnerId = this.activePartnerData.Id;

            this.strategiesData = { ...event.detail };

            const partnerIndex = this.partners.findIndex(p => p.Id === partnerId);
            if (partnerIndex !== -1) {
                this.partners[partnerIndex] = {
                    ...this.partners[partnerIndex],
                    strategiesData: { ...this.strategiesData }
                };
            }

            this.activePartnerData = {
                ...this.activePartnerData,
                strategiesData: { ...this.strategiesData }
            };

            this.currentStrategiesPartnerId = partnerId;
        }
    }

    handleAddNewPartner() {
        this.saveCurrentStrategiesData();

        this.isEditingExistingPartner = false;
        this.currentPartnerIndex = this.partners.length;
        this.currentPartnerData = {};
        this.activePartnerData = {};
        this.isCurrentPartnerValid = false;
        this.isWorkingWithPartner = true;
        this.strategiesData = {};
        this.currentStrategiesPartnerId = null;

        this.currentStep = 2;

        setTimeout(() => {
            const stepTwoComponent = this.template.querySelector('c-g-p-sform-step-two');
            if (stepTwoComponent) {
                stepTwoComponent.resetForm();
            }
        }, 100);
    }

    handleEditPartner(event) {
        const partnerId = parseInt(event.currentTarget.dataset.partnerId);

        this.saveCurrentStrategiesData();

        const partnerIndex = this.partners.findIndex(p => p.Id === partnerId);

        if (partnerIndex !== -1) {
            const partnerToEdit = this.partners[partnerIndex];
            this.currentPartnerIndex = partnerIndex;
            this.isEditingExistingPartner = true;
            this.currentPartnerData = { ...partnerToEdit };
            this.activePartnerData = { ...partnerToEdit };
            this.isCurrentPartnerValid = true;
            this.isWorkingWithPartner = true;

            this.strategiesData = partnerToEdit.strategiesData || {};
            this.currentStrategiesPartnerId = partnerId;

            this.currentStep = 2;

            setTimeout(() => {
                const stepTwoComponent = this.template.querySelector('c-g-p-sform-step-two');
                if (stepTwoComponent) {
                    stepTwoComponent.setPartnerData(this.currentPartnerData);
                }
            }, 100);
        }
    }

    handleDeletePartner(event) {
        const partnerId = parseInt(event.currentTarget.dataset.partnerId);
        this.partners = this.partners.filter(p => p.Id !== partnerId);

        this.partners = this.partners.map((partner, index) => ({
            ...partner,
            Id: index + 1
        }));

        if (this.activePartnerData && this.activePartnerData.Id === partnerId) {
            if (this.partners.length > 0) {
                this.activePartnerData = { ...this.partners[0] };
                this.strategiesData = this.partners[0].strategiesData || {};
                this.currentStrategiesPartnerId = this.partners[0].Id;
            } else {
                this.activePartnerData = {};
                this.strategiesData = {};
                this.currentStrategiesPartnerId = null;
                this.isWorkingWithPartner = false;
            }
        }

        if (this.partners.length === 0) {
            this.currentStep = 1;
            // Reset all partner-related data when no partners remain
            this.isEditingExistingPartner = false;
            this.currentPartnerData = {};
            this.activePartnerData = {};
            this.isCurrentPartnerValid = false;
            this.isWorkingWithPartner = false;
            this.strategiesData = {};
            this.currentStrategiesPartnerId = null;
        }

        this.showToast('Success', 'Partner removed successfully!', 'success');
    }

    async handleSaveAsDraft() {
        this.isLoading = true;

        try {
            if (this.currentStep === 2) {
                const stepTwoComponent = this.template.querySelector('c-g-p-sform-step-two');
                if (stepTwoComponent && stepTwoComponent.validatePartner()) {
                    this.saveCurrentPartner();
                }
            } else if (this.currentStep === 3) {
                this.saveCurrentStrategiesData();
                const stepThreeComponent = this.template.querySelector('c-g-p-sform-step-three');
                if (stepThreeComponent) {
                    const validationResult = stepThreeComponent.validateAllFields();
                    if (!validationResult.isValid) {
                        this.showToast('Error', 'Please correct the errors before saving as draft', 'error');
                        return;
                    }
                }
            }

            const applicationData = {
                ...this.formData,
                UploadedFiles: this.uploadedFiles,
                Partners: this.partners,
                Application_Status__c: 'Draft'
            };

            if (this.isExistingApplication && this.applicationId) {
                await updateFundingApplication({
                    applicationId: this.applicationId,
                    applicationData: applicationData
                });
                this.showToast('Success', 'Your application draft has been updated.', 'success');

                this.handlePostSubmission();
            } else {
                const newApplicationId = await createFundingApplication({ applicationData: applicationData });
                this.applicationId = newApplicationId;
                this.isExistingApplication = true;

                const newUrl = `${window.location.pathname}?Id=${newApplicationId}`;
                window.history.replaceState({}, '', newUrl);

                this.showToast('Success', 'Your application has been saved as a draft.', 'success');
                this.handlePostSubmission();
            }
        } catch (error) {
            console.error('Draft save error:', error);
            this.showToast('Error', `Failed to save draft: ${error.body?.message || 'Unknown error'}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSaveAndExit() {
        this.handleSaveAsDraft();
    }

    saveCurrentPartner() {
        const stepTwoComponent = this.template.querySelector('c-g-p-sform-step-two');
        if (!stepTwoComponent) {
            console.error('Step two component not found');
            return false;
        }

        if (!stepTwoComponent.validatePartner()) {
            this.showToast('Error', 'Please fill in all required partner fields', 'error');
            return false;
        }

        const partnerData = stepTwoComponent.getPartnerData();

        if (this.isEditingExistingPartner) {
            this.partners[this.currentPartnerIndex] = {
                ...partnerData,
                Id: this.partners[this.currentPartnerIndex].Id,
                strategiesData: this.partners[this.currentPartnerIndex].strategiesData || {}
            };
            this.activePartnerData = { ...this.partners[this.currentPartnerIndex] };
            this.showToast('Success', 'Partner updated successfully!', 'success');
        } else {
            const newPartner = {
                ...partnerData,
                Id: this.partners.length + 1,
                strategiesData: {}
            };
            this.partners = [...this.partners, newPartner];
            this.activePartnerData = { ...newPartner };
            this.strategiesData = {};
            this.currentStrategiesPartnerId = newPartner.Id;
            this.showToast('Success', 'Partner added successfully!', 'success');
        }

        this.currentPartnerData = { ...this.activePartnerData };
        this.isWorkingWithPartner = true;
        return true;
    }

    handleAddPartnerFromStep3() {
        this.saveCurrentStrategiesData();

        const stepThreeComponent = this.template.querySelector('c-g-p-sform-step-three');

        if (stepThreeComponent) {
            const validationResult = stepThreeComponent.validateAllFields();

            if (!validationResult.isValid) {
                this.showToast('Error', 'Please correct the errors before proceeding', 'error');
                return;
            }
        }

        this.isEditingExistingPartner = false;
        this.currentPartnerIndex = this.partners.length;
        this.currentPartnerData = {};
        this.activePartnerData = {};
        this.isCurrentPartnerValid = false;
        this.isWorkingWithPartner = true;
        this.strategiesData = {};
        this.currentStrategiesPartnerId = null;

        this.currentStep = 2;

        setTimeout(() => {
            this.template.querySelector('c-g-p-sform-step-two')?.resetForm();
        }, 100);
    }

    saveCurrentStrategiesData() {
        if (this.activePartnerData && this.activePartnerData.Id && this.strategiesData) {
            const partnerIndex = this.partners.findIndex(p => p.Id === this.activePartnerData.Id);
            if (partnerIndex !== -1) {
                this.partners[partnerIndex] = {
                    ...this.partners[partnerIndex],
                    strategiesData: { ...this.strategiesData }
                };
            }
        }
    }

    handleNext() {
        console.log('Form data before validation:', JSON.stringify(this.formData, null, 2));

        let allValid = true;

        if (this.currentStep === 1) {
            console.log('File Uploaded Files:', JSON.stringify(this.uploadedFiles));

            const stepOneComponent = this.template.querySelector('c-g-p-sform-step-one');
            if (stepOneComponent && stepOneComponent.validateStep) {
                allValid = stepOneComponent.validateStep();
            }
        } else if (this.currentStep === 2) {
            allValid = this.saveCurrentPartner();
        } else if (this.currentStep === 3) {
            if (this.partners.length === 0) {
                this.showToast('Error', 'Please add at least one partner before proceeding', 'error');
                allValid = false;
            }

            const stepThreeComponent = this.template.querySelector('c-g-p-sform-step-three');

            if (stepThreeComponent) {
                const validationResult = stepThreeComponent.validateAllFields();
                allValid = validationResult.isValid;
            }

            this.saveCurrentStrategiesData();
        }

        if (allValid) {
            this.currentStep++;
            if (this.currentStep === 3) {
                this.isWorkingWithPartner = true;
                this.loadStrategiesForActivePartner();
            } else if (this.currentStep === 2) {
                // If no partners exist, reset to add new partner mode
                if (this.partners.length === 0) {
                    this.isEditingExistingPartner = false;
                    this.currentPartnerData = {};
                    this.activePartnerData = {};
                    this.isCurrentPartnerValid = false;
                    this.isWorkingWithPartner = false;
                    this.strategiesData = {};
                    this.currentStrategiesPartnerId = null;
                } else {
                    this.loadPartnerData();
                }
            }
        } else {
            this.showToast('Error', 'Please correct the errors before proceeding', 'error');
        }
    }

    loadStrategiesForActivePartner() {
        if (this.activePartnerData && this.activePartnerData.Id) {
            this.strategiesData = this.activePartnerData.strategiesData || {};
            this.currentStrategiesPartnerId = this.activePartnerData.Id;

            setTimeout(() => {
                const stepThreeComponent = this.template.querySelector('c-g-p-sform-step-three');
                if (stepThreeComponent && stepThreeComponent.loadStrategiesData) {
                    stepThreeComponent.loadStrategiesData(this.strategiesData);
                }
            }, 100);
        }
    }

    handlePrevious() {
        if (this.currentStep > 1) {
            if (this.currentStep === 3) {
                this.saveCurrentStrategiesData();
            }

            this.currentStep--;

            if (this.currentStep === 2 && this.activePartnerData && Object.keys(this.activePartnerData).length > 0) {
                this.loadPartnerData();
            } else if (this.currentStep === 1) {
                this.isEditingExistingPartner = false;
                this.currentPartnerData = {};
                this.isWorkingWithPartner = false;
            } else if (this.currentStep === 3) {
                this.loadStrategiesForActivePartner();
            }
        }
    }
 
    loadPartnerData() {
        this.currentPartnerData = { ...this.activePartnerData };
        this.isCurrentPartnerValid = true;
        this.isWorkingWithPartner = true;
        
        // Check if activePartnerData has an Id before trying to find the partner
        if (this.activePartnerData && this.activePartnerData.Id) {
            const partnerIndex = this.partners.findIndex(p => p.Id === this.activePartnerData.Id);
            if (partnerIndex !== -1) {
                this.currentPartnerIndex = partnerIndex;
                this.isEditingExistingPartner = true;
            }
        }
        
        setTimeout(() => {
            this.template.querySelector('c-g-p-sform-step-two')?.setPartnerData(this.currentPartnerData);
        }, 100);
    }

    switchToPartner(partnerId) {
        this.saveCurrentStrategiesData();

        const partner = this.partners.find(p => p.Id === partnerId);
        if (partner) {
            this.activePartnerData = { ...partner };
            this.strategiesData = partner.strategiesData || {};
            this.currentStrategiesPartnerId = partnerId;

            setTimeout(() => {
                const stepThreeComponent = this.template.querySelector('c-g-p-sform-step-three');
                if (stepThreeComponent && stepThreeComponent.loadStrategiesData) {
                    stepThreeComponent.loadStrategiesData(this.strategiesData);
                }
            }, 100);
        }
    }

    async handleSubmitApplication() {
        if (!this.validateCompleteApplication()) {
            return;
        }

        this.saveCurrentStrategiesData();
        this.isLoading = true;

        try {
            const applicationData = {
                ...this.formData,
                Application_Status__c: 'Submitted',
                UploadedFiles: this.uploadedFiles,
                Partners: this.partners
            };

            console.log('Final Application Data to be sent to Apex:', JSON.stringify(applicationData, null, 2));

            if (this.isExistingApplication && this.applicationId) {
                await updateFundingApplication({
                    applicationId: this.applicationId,
                    applicationData: applicationData
                });
                this.showToast('Success', 'Funding Application updated and submitted successfully!', 'success');
            } else {
                const newApplicationId = await createFundingApplication({ applicationData: applicationData });
                this.applicationId = newApplicationId;
                this.showToast('Success', 'Funding Application submitted successfully!', 'success');
            }

            this.handlePostSubmission();

        } catch (error) {
            console.error('Submission error:', error);
            this.showToast('Error', `Failed to submit application: ${error.body?.message || 'Unknown error'}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleFinishApplication() {
        this.handleSubmitApplication();
    }

    validateCompleteApplication() {
        let isValid = true;
        const errors = [];

        // Validate step 1
        const stepOneComponent = this.template.querySelector('c-g-p-sform-step-one');
        if (stepOneComponent && stepOneComponent.validateStep && !stepOneComponent.validateStep()) {
            errors.push('Please complete all required fields in Application Information');
            isValid = false;
        }

        if (this.partners.length === 0) {
            errors.push('Please add at least one partner');
            isValid = false;
        }

        for (let partner of this.partners) {
            if (!partner.Partner_Name__c) {
                errors.push(`Partner ${partner.Id} is missing required information`);
                isValid = false;
            }
        }

        if (!isValid) {
            this.showToast('Validation Error', errors.join('. '), 'error');
        }

        return isValid;
    }

    handlePostSubmission() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            },
            state: {
                c__ActiveTab: 'projects'
            }
        });

        this.originalApplicationStatus = 'Submitted';
    }



    resetForm() {
        this.formData = { Application_Status__c: 'Draft' };
        this.currentStep = 1;
        this.errors = {};
        this.uploadedFiles = [];
        this.isStepValid = false;
        this.partners = [];
        this.currentPartnerData = {};
        this.isCurrentPartnerValid = false;
        this.currentPartnerIndex = 0;
        this.isEditingExistingPartner = false;
        this.activePartnerData = {};
        this.isWorkingWithPartner = false;
        this.strategiesData = {};
        this.currentStrategiesPartnerId = null;
        this.isExistingApplication = false;
        this.applicationId = null;
        this.originalApplicationStatus = null;
        this.hasDataLoaded = false;

        window.history.replaceState({}, '', window.location.pathname);

        this.initializeForm();
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant, mode: 'dismissible' });
        this.dispatchEvent(event);
    }

    // Getters
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isFirstStep() { return this.currentStep === 1; }
    get isLastStep() { return this.currentStep === this.totalSteps; }
    get isStep3OrLater() { return this.currentStep >= 3; }
    get progressPercentage() { return (this.currentStep / this.totalSteps) * 100; }
    get partnersCount() { return this.partners.length; }

    get currentPartnerNumber() {
        return this.isEditingExistingPartner || (this.activePartnerData && this.activePartnerData.Id)
            ? this.activePartnerData.Id
            : this.partners.length + 1;
    }

    get isAddPartnerDisabled() { return this.isLoading || !this.isCurrentPartnerValid; }
    get stepTwoTitle() { return this.isEditingExistingPartner ? 'Edit Partner Information' : 'Add Partner Information'; }
    get canProceedFromStep2() { return this.partners.length > 0 || this.isCurrentPartnerValid; }
    get hasActivePartner() { return this.activePartnerData && Object.keys(this.activePartnerData).length > 0; }
    get hasPartners() { return this.partners.length > 0; }

    // New getters for enhanced functionality
    get isExistingDraft() {
        return this.isExistingApplication && this.originalApplicationStatus === 'Draft';
    }

    get isExistingSubmitted() {
        return this.isExistingApplication && this.originalApplicationStatus === 'Submitted';
    }

    get formTitle() {
        if (this.isExistingSubmitted) {
            return 'View Submitted Application';
        } else if (this.isExistingDraft) {
            return 'Edit Draft Application';
        } else {
            return 'New GPS Funding Application';
        }
    }

    get isFormDisabled() {
        return this.isExistingSubmitted;
    }

    get submitButtonLabel() {
        return this.isExistingApplication ? 'Update and Submit' : 'Submit Application';
    }

    get draftButtonLabel() {
        return this.isExistingApplication ? 'Update Draft' : 'Save as Draft';
    }

    get isStep2and4Disabled() {
        return this.currentStep === 1 || this.currentStep === 3;
    }

    handlePreview() {
        this.isPreviewOpen = true;
    }

    handleClosePreview() {
        this.isPreviewOpen = false;
    }
}