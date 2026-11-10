import { application } from "controllers/application"
import TranslationFormController from "controllers/translation_form_controller"
import ClipboardController from "controllers/clipboard_controller"
application.register("translation-form", TranslationFormController)
application.register("clipboard", ClipboardController)
import TranslationProgressController from "controllers/translation_progress_controller"
application.register("translation-progress", TranslationProgressController)
import TranslationSourceController from "controllers/translation_source_controller"
application.register("translation-source", TranslationSourceController)
import PreferenceController from "controllers/preference_controller"
application.register("preference", PreferenceController)
import ConnectionProbeController from "controllers/connection_probe_controller"
application.register("connection-probe", ConnectionProbeController)
import DeploymentFormController from "controllers/deployment_form_controller"
application.register("deployment-form", DeploymentFormController)
import WorkspaceNavController from "controllers/workspace_nav_controller"
application.register("workspace-nav", WorkspaceNavController)
import TranslationCompareController from "controllers/translation_compare_controller"
application.register("translation-compare", TranslationCompareController)
