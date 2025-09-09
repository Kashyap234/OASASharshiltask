import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getContentDistributionUrl from '@salesforce/apex/FundingApplicationController.getContentDistributionUrl';

export default class GpsPreviewModal extends NavigationMixin(LightningElement) {
    @api formData = {};
    @api partners = [];
    @api uploadedFiles = [];
    @api totalAmountRequested = 0;

    get hasPartners() {
        return this.partners && this.partners.length > 0;
    }

    get hasUploadedFiles() {
        return this.uploadedFiles && this.uploadedFiles.length > 0;
    }
    
    get applicationDetails() {
        const fieldLabels = {
            Name_of_Person_Completing_Form__c: 'Person Completing Form',
            Entity_Type__c: 'Entity Type',
            Proposed_Project_Title__c: 'Proposed Project Title',
            OrganizationAddressLine1__c: 'Organization Address 1',
            OrganizationAddressLine2__c: 'Organization Address 2',
            OrganizationCity__c: 'Organization City',
            OrganizationState__c: 'Organization State',
            OrganizationZip__c: 'Organization Zip',
            Fiscal_Manager_Title__c: 'Fiscal Manager Title',
            Fiscal_Manager_Email__c: 'Fiscal Manager Email',
            Fiscal_Manager_Phone_Number__c: 'Fiscal Manager Phone',
            Program_Manager_Name__c: 'Program Manager Name',
            Program_Manager_Email__c: 'Program Manager Email',
            Program_Manager_Phone_Number__c: 'Program Manager Phone',
            SCEIS_Vendor_Number__c: 'SCEIS Vendor Number',
            Address_Line_1__c: 'Mailing Address 1',
            Address_Line_2__c: 'Mailing Address 2',
            City__c: 'Mailing City',
            Zip__c: 'Mailing Zip'
        };

        return Object.keys(fieldLabels)
            .filter(key => this.formData[key]) 
            .map(key => {
                return {
                    label: fieldLabels[key],
                    value: this.formData[key],
                    id: key
                };
            });
    }

    get processedPartners() {
        if (!this.hasPartners) {
            return [];
        }

        return this.partners.map(partner => {
            const strategiesData = partner.strategiesData || {};
            const strategyData = strategiesData.strategyData || {};
            const strategyResourcesData = strategiesData.strategyResourcesData || {};

            const strategyDetails = Object.keys(strategyData).map(key => {
                const resources = strategyResourcesData[key] || { personnel: [], budget: [] };
                return {
                    name: key,
                    details: strategyData[key],
                    personnel: resources.personnel,
                    budget: resources.budget,
                    hasPersonnel: resources.personnel?.length > 0,
                    hasBudget: resources.budget?.length > 0
                };
            });

            return {
                ...partner, 
                strategyDetails: strategyDetails,
                hasCoreStrategies: strategiesData.selectedCoreStrategies?.length > 0,
                hasCoreAbatements: strategiesData.selectedCoreAbatements?.length > 0,
                hasApprovedUses: strategiesData.selectedApprovedUses?.length > 0,
                hasApprovedAbatements: strategiesData.selectedApprovedAbatements?.length > 0,
            };
        });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleViewFile(event){
        console.log(event.target.dataset.id);
        this.handlePreviewDocument(event.target.dataset.id);
    }

    async handlePreviewDocument(documentId) {
        try {
            await getContentDistributionUrl({ documentId: documentId })
                .then(distributionUrl => {
                    console.log('Content Distribution URL:', distributionUrl);
                    window.open(distributionUrl, '_blank');
                })
                .catch(error => {
                    console.error('Error getting distribution URL:', error);
                    this.showToast('Error', 'Unable to create file preview link', 'error');
                });

            console.log('Document preview opened successfully');

        } catch (error) {
            console.error(JSON.stringify(error));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Unable to preview the document.',
                    variant: 'error'
                })
            );
        }
    }
}