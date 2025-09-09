import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getApplications from '@salesforce/apex/FundingApplicationController.getApplications';
import getApplicationData from '@salesforce/apex/GPSApplicationController.getFundingApplication';

const columns = [
    { label: 'Application Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Request Type', fieldName: 'Request_Type__c', type: 'text' },
    { label: 'Status', fieldName: 'Application_Status__c', type: 'text' },
    { label: 'Date', fieldName: 'Date__c', type: 'date-local', sortable: true, typeAttributes: { month: "2-digit", day: "2-digit", year: "numeric" } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: (row, doneCallback) => {
                const actions = [];
                actions.push({ label: 'View', name: 'view', iconName: 'utility:preview' });

                if (row['Application_Status__c'] === 'Draft') {
                    actions.push({ label: 'Edit', name: 'edit', iconName: 'utility:edit' });
                    actions.push({ label: 'Delete', name: 'delete', iconName: 'utility:delete' });
                }

                doneCallback(actions);
            }
        }
    }
];

export default class FundingApplicationTable extends NavigationMixin(LightningElement) {
    formData = {};
    partners = [];
    uploadedFiles = [];
    totalAmountRequested = 0;
    columns = columns;
    wiredApplicationsResult;
    isLoading = true;
    showDeleteModal = false;
    recordToDeleteId = null;
    showModal = false;


    get showEmptyState() {
        return !this.isLoading && this.data.length === 0;
    }

    connectedCallback() {
        this.getData();
    }

    async getData() {
        this.isLoading = true;
        await getApplications()
            .then(data => {
                this.data = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load applications.', 'error');
                this.data = [];
                this.isLoading = false;
            });
    }

    // @wire(getApplications)
    // wiredApplications(result) {
    //     this.isLoading = true;
    //     this.wiredApplicationsResult = result;
    //     if (result.data) {
    //         this.data = result.data;
    //         this.isLoading = false;
    //     } else if (result.error) {
    //         this.showToast('Error', 'Failed to load applications.', 'error');
    //         this.data = [];
    //         this.isLoading = false;
    //     }
    // }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'view':
                this.viewApplication(row.Id);
                break;
            case 'edit':
                this.navigateToRecordPage(row.Id, 'edit');
                break;
            case 'delete':
                this.recordToDeleteId = row.Id;
                this.showDeleteModal = true;
                break;
            default:
        }
    }

    handleNewClick() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'GPS_Application__c',
            }
        });
    }

    handleRefresh() {
        this.getData();
    }

    viewApplication(recordId) {
        this.handleGetApplicationData(recordId);
        this.showModal = true;
    }

    async handleGetApplicationData(recordId) {
        await getApplicationData({ applicationId: recordId })
            .then(data => {
                console.log('Application data loaded:', JSON.stringify(data, null, 2));

                this.formData = data;
                this.partners = data.Partners || [];
                this.uploadedFiles = data.UploadedFiles || [];
                this.totalAmountRequested = data.totalAmountRequested || 0;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load application data.', 'error');
                console.error('Error loading application data:', error);
            });
    }

    navigateToRecordPage(recordId, actionName) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'GPS_Application__c'
            },
            state: {
                id: recordId
            }
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    handleClosePreview() {
        this.showModal = false;
    }
}