import { LightningElement, track} from 'lwc';
import isApplicationOpen from '@salesforce/apex/ServiceUtility.isApplicationOpen';
import isApplicationOpenWithUserEligibility from '@salesforce/apex/ServiceUtility.isApplicationOpenWithUserEligibility';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';

export default class GPSApplication extends LightningElement {
    @track isLoading = false;
    @track applicationOpen = false;
    @track isEligibleToApply = true;

    connectedCallback() {
        this.checkApplicationStatus();
    }

    async checkApplicationStatus() {
        try {
            this.isLoading = true;
            this.applicationOpen = await isApplicationOpen();

            if(this.applicationOpen) {
                this.isEligibleToApply = await isApplicationOpenWithUserEligibility({ userId: USER_ID });
            }

            this.applicationOpen = result.isEligibleToApply;

            console.log('Application Open Status:', this.result.isEligibleToApply);
            
        } catch (error) {
            console.log('in')
        } finally {
            console.log('finally')
            this.isLoading = false;
        }

        console.log(this.isLoading);
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    refreshStatus() {
        this.checkApplicationStatus();
    }
}