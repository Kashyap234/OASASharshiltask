import { LightningElement, track, wire} from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME from '@salesforce/schema/User.FirstName';
import USER_NAME_LAST from '@salesforce/schema/User.LastName';
import USER_EMAIL from '@salesforce/schema/User.Email';

export default class ScorfDashBoard extends LightningElement {
    @track activeTab = 'dashboard';
    @track userRecord;

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME, USER_NAME_LAST, USER_EMAIL ]})
    wiredUser({ error, data }) {
        if (data) {
            this.userRecord = data;
            console.log(JSON.stringify(this.userRecord));
        } else if (error) {
            console.error('Error user record:', error);
        }
    }

    connectedCallback() {
        // Get active tab from Url
        const urlParams = new URLSearchParams(window.location.search);
        this.activeTab = urlParams.get('c__ActiveTab');
        if (!this.activeTab) {
            this.activeTab = 'dashboard';
        }

        this.navigation = this.navigation.map(item => ({
            ...item,
            isActive: item.key === this.activeTab,
            class: item.key === this.activeTab ? 'nav-active' : ''
        }));
    }
    
    get firstName() {
        return this.userRecord ? getFieldValue(this.userRecord, USER_NAME) : '';
        // return this.userRecord?.fields?.[USER_NAME.fieldApiName]?.value || '';
    }
    
    get lastName() {
        return this.userRecord ? getFieldValue(this.userRecord, USER_NAME_LAST) : '';
        // return this.userRecord?.fields?.[USER_NAME_LAST.fieldApiName]?.value || '';
    }
    
    get email() {
        return this.userRecord ? getFieldValue(this.userRecord, USER_EMAIL) : '';
        // return this.userRecord?.fields?.[USER_EMAIL.fieldApiName]?.value || '';
    }

    get userInfo() {
        return {
            name: `${this.firstName} ${this.lastName}`,
            email: this.email,
        };
    }

    @track navigation = [
        { 
            key: 'dashboard', 
            label: 'Dashboard', 
            icon: 'utility:home',
            class: 'nav-active',
            isActive: true
        },
        {
            key: 'projects', 
            label: 'Projects', 
            icon: 'utility:apps',
            class: '',
            isActive: false 
        },
        { 
            key: 'letters', 
            label: 'Letter of Intent', 
            icon: 'utility:file',
            class: '',
            isActive: false 
        },
        { 
            key: 'reports', 
            label: 'Reports', 
            icon: 'utility:chart',
            class: '',
            isActive: false 
        },
        {
            key: 'closeOut',
            label: 'Close Out Packege',
            icon: 'utility:loop',
            class: '',
            isActive: false
        }
    ];

    handleNavigation(event) {
        const temp = event.currentTarget.dataset.tab;
        this.activeTab = temp;

        this.navigation = this.navigation.map(item => ({
            ...item,
            isActive: item.key === temp,
            class: item.key === temp ? 'nav-active' : ''
        }));
    }

    get isDashboardActive() {
        return this.activeTab === 'dashboard';
    }

    get isProjectsActive() {
        return this.activeTab === 'projects';
    }

    get isLettersActive() {
        return this.activeTab === 'letters';
    }

    get isReportsActive() {
        return this.activeTab === 'reports';
    }

    get isCloseOutActive() {
        return this.activeTab === 'closeOut';
    }
}