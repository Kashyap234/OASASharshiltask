import { LightningElement , track} from 'lwc';

export default class DisplayDashboard extends LightningElement {
    
    @track height = '800px';
    baseUrl = 'https://orgfarm-702fc43f52-dev-ed.develop.my.site.com'
    path = '/s/dashboard-data';

    url = this.baseUrl + this.path;
    @track width = '100%';

    
}