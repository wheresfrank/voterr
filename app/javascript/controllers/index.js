// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import Clipboard from '@stimulus-components/clipboard'

// Load all the controllers within this directory and all subdirectories. 
// Controller files must be named *_controller.js.
eagerLoadControllersFrom("controllers", application)

// Register the Clipboard controller
application.register('clipboard', Clipboard)