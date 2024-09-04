import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "status" ]
  
  static values = {
    plexBaseUrl: String,
    plexProduct: String,
    plexVersion: String,
    clientId: String,
    browserName: String,
    browserVersion: String,
    device: String,
    deviceName: String,
    callbackUrl: String
  }

  async initiate() {
    this.statusTarget.textContent = "Initiating Plex authentication..."
    try {
      const pin = await this.generatePlexPin()
      const authUrl = this.constructAuthUrl(pin.code)
      window.open(authUrl, '_blank')
      await this.checkPinStatus(pin.id)
    } catch (error) {
      console.error('Plex authentication failed:', error)
      this.statusTarget.textContent = 'Failed to authenticate with Plex. Please try again.'
    }
  }

  async generatePlexPin() {
    const response = await fetch(`${this.plexBaseUrlValue}/api/v2/pins`, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'X-Plex-Product': this.plexProductValue,
        'X-Plex-Version': this.plexVersionValue,
        'X-Plex-Client-Identifier': this.clientIdValue
      },
      body: new URLSearchParams({ 'strong': 'true' })
    })

    if (!response.ok) {
      throw new Error('Failed to generate Plex PIN')
    }

    return response.json()
  }

  constructAuthUrl(pinCode) {
    const params = new URLSearchParams({
      clientID: this.clientIdValue,
      code: pinCode,
      'context[device][product]': this.plexProductValue,
      'context[device][version]': this.plexVersionValue,
      'context[device][platform]': this.browserNameValue,
      'context[device][platformVersion]': this.browserVersionValue,
      'context[device][device]': this.deviceValue,
      'context[device][deviceName]': this.deviceNameValue,
      'context[device][model]': 'Plex OAuth'
    })

    return `https://app.plex.tv/auth#!?${params.toString()}`
  }

  async checkPinStatus(pinId) {
    this.statusTarget.textContent = "Waiting for Plex authentication..."
    const maxAttempts = 60 // 1 minute of checking
    for (let i = 0; i < maxAttempts; i++) {
      const response = await fetch(`${this.plexBaseUrlValue}/api/v2/pins/${pinId}`, {
        headers: {
          'Accept': 'application/json',
          'X-Plex-Client-Identifier': this.clientIdValue
        }
      })

      if (!response.ok) {
        throw new Error('Failed to check PIN status')
      }

      const data = await response.json()
      if (data.authToken) {
        await this.sendAuthTokenToServer(data.authToken)
        return
      }

      await new Promise(resolve => setTimeout(resolve, 1000)) // Wait 1 second before checking again
    }

    throw new Error('PIN authentication timed out')
  }

  async sendAuthTokenToServer(authToken) {
    console.log('Sending auth token to server:', authToken);
    try {
      const response = await fetch('/plex_auth/callback', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ plex_auth: { auth_token: authToken } })
      });
  
      console.log('Response status:', response.status);
      const result = await response.json();
      console.log('Response body:', result);
      result
      if (result.success) {
        this.statusTarget.textContent = result.message;
        window.location.href = '/';
      } else {
        throw new Error(result.message);
      }
    } catch (error) {
      console.error('Error during authentication:', error);
      this.statusTarget.textContent = 'Authentication failed. Please try again.';
    }
  }
}