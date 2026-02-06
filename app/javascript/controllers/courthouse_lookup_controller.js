import { Controller } from '@hotwired/stimulus';

// Courthouse Lookup Controller
// Shows contact info for selected CA county
export default class extends Controller {
  static targets = ['select', 'info', 'name', 'address', 'phone', 'link'];

  connect() {
    this.update();
  }

  update() {
    const county = this.selectTarget.value;
    const courthouseData = this.getCourthouseData();
    const info = courthouseData[county];

    if (info) {
      this.nameTarget.textContent = info.name;
      this.addressTarget.textContent = info.address;
      this.phoneTarget.textContent = info.phone;
      this.linkTarget.href = info.url;
      this.infoTarget.classList.remove('hidden');
    } else {
      this.infoTarget.classList.add('hidden');
    }
  }

  getCourthouseData() {
    // This could be fetched from an API or embedded in the view as JSON
    // For now, we'll embed it in the controller or pass via data value
    return JSON.parse(this.element.dataset.courthouseLookupData || '{}');
  }
}
