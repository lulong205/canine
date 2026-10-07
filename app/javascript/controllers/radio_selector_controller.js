import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "partial"]
  // Disabled fields aren't submitted, so hidden alternatives sharing a field name can't overwrite the visible one
  static values = { disableHidden: Boolean }

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedRadio = this.radioTargets.find(radio => radio.checked)

    if (selectedRadio) {
      const selectedValue = selectedRadio.value

      this.partialTargets.forEach(partial => {
        const selected = partial.dataset.value === selectedValue
        if (selected) {
          partial.classList.remove('hidden')
        } else {
          partial.classList.add('hidden')
        }
        if (this.disableHiddenValue) {
          partial.querySelectorAll('input, select, textarea').forEach(field => { field.disabled = !selected })
        }
      })
    }
  }
}
