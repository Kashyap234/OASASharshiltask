import { LightningElement, api, wire, track } from 'lwc';
import getAnalyzedNotesForAccount from '@salesforce/apex/ContentNoteAnalyzer.getAnalyzedNotesForAccount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NoteAnalyzer extends LightningElement {
    @api recordId; 
    @track notesWithMatches = [];
    @track hasNotesWithMatches = false;
    @track isLoading = false;
    @track error;
    @track hasHighPriority = false;
    @track hasMediumPriority = false;
    @track totalMatches = 0;

    @wire(getAnalyzedNotesForAccount, { accountId: '$recordId' })
    wiredNotes({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.analyzedNotes = data.map(note => ({
                ...note,
                formattedCreatedDate: new Date(note.createdDate).toLocaleDateString(),
                formattedLastModifiedDate: new Date(note.lastModifiedDate).toLocaleDateString(),
                importanceClass: this.getImportanceClass(note.importanceLevel),
                importanceIcon: this.getImportanceIcon(note.importanceLevel),
                matchedWordsString: note.matchedWords ? note.matchedWords.join(', ') : '',
                hasMatches: note.matchedWords && note.matchedWords.length > 0,
                shortContent: this.truncateContent(note.content, 150)
            }));
            
            // Filter to only show notes with matches
            this.notesWithMatches = this.analyzedNotes.filter(note => note.hasMatches);
            this.hasNotesWithMatches = this.notesWithMatches.length > 0;
            
            this.calculateSummary();
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unknown error occurred';
            this.analyzedNotes = [];
            this.notesWithMatches = [];
            this.hasNotesWithMatches = false;
            console.error('Error loading notes:', error);
        }
    }

    calculateSummary() {
        this.hasHighPriority = this.analyzedNotes.some(note => note.importanceLevel === 'HIGH');
        this.hasMediumPriority = this.analyzedNotes.some(note => note.importanceLevel === 'MEDIUM');
        this.totalMatches = this.analyzedNotes.reduce((sum, note) => sum + (note.matchCount || 0), 0);
    }

    getImportanceClass(level) {
        switch(level) {
            case 'HIGH': return 'importance-high';
            case 'MEDIUM': return 'importance-medium';
            case 'LOW': return 'importance-low';
            default: return 'importance-none';
        }
    }

    getImportanceIcon(level) {
        switch(level) {
            case 'HIGH': return 'utility:error';
            case 'MEDIUM': return 'utility:warning';
            case 'LOW': return 'utility:info';
            default: return 'utility:success';
        }
    }

    truncateContent(content, maxLength) {
        if (!content) return '';
        return content.length > maxLength ? content.substring(0, maxLength) + '...' : content;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    get hasNotes() {
        return this.hasNotesWithMatches;
    }

    get alertClass() {
        if (this.hasHighPriority) return 'alert-high';
        if (this.hasMediumPriority) return 'alert-medium';
        return 'alert-low';
    }

    get analyzedNotesAvailable() {
        return this.analyzedNotes.filter(note => note.hasMatches).length > 0;
    }

    get alertMessage() {
        if (this.hasHighPriority) {
            return `Critical keywords detected in notes`;
        }
        if (this.hasMediumPriority) {
            return `Important keywords found in notes`;
        }
        if (this.totalMatches > 0) {
            return `ℹ️ Keywords found in notes - review recommended`;
        }
        return '✅ No concerning keywords detected';
    }
}