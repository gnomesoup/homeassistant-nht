(require 'json)

(setq hass-api/token (mjp/match-file-contents "hass-token ?= ?\\(.*\\)"
                                              "~/hassio-config-euler/hass-token.txt"))
(setq hass-api/url (mjp/match-file-contents "hass-url ?= ?\\(.*\\)"
                                            "~/hassio-config-euler/hass-token.txt"))
(defun hass-api/connection-check (host)
  (if (= 0 (call-process "ping" nil nil nil "-c" "1" "-W" "1"
                   (replace-regexp-in-string
                    "^https?:\\/\\/" "" host nil)))
      t
    (message "Unable to connect to home assistant at %s" host)))

(defun mjp/match-file-contents (regex filePath)
  "Matches a regular expression with contents in another file"
  (let ((fContents (with-temp-buffer (insert-file-contents filePath nil)
                                     (buffer-string))))
    (string-match regex fContents)
    (match-string 1 fContents)))


(spacemacs/declare-prefix "ah" "hass-api")
(spacemacs/declare-prefix "ahr" "refresh")
(replace-regexp-in-string "^https?:\\/\\/" "" hass-api/url nil)
(defun hass-api/get-all-entities-as-list()
  "Use curl to grab a list of all entities from home assistant"
  (when (hass-api/connection-check hass-api/url)
      (let* ((entity_ids (shell-command-to-string
                          (concat "curl -s -H \"Content-Type: application/json\" "
                              "-H \"Authorization: Bearer "
                              hass-api/token
                              "\" "
                              hass-api/url
                              "/api/template "
                              "-d"
                              "\"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\n{% endfor %}\\\"}\""))))
    (split-string entity_ids "\n"))))
(defun hass-api/refresh-entities()
  "Download latest entities from Home Assistant"
  (interactive)
  (setq hass-api/entities (hass-api/get-all-entities-as-list)))

(hass-api/refresh-entities)
(spacemacs/set-leader-keys "ahre" 'hass-api/refresh-entities)

(defun hass-api/get-all-entities-and-names-as-list()
  "Use curl to grab a list of all entities and their friendly names from home assistant"
  (when (hass-api/connection-check hass-api/url)
    (let* ((entity_ids (shell-command-to-string
                        (concat "curl -s -H \"Content-Type: application/json\" "
                                "-H \"Authorization: Bearer "
                                hass-api/token
                                "\" \""
                                hass-api/url
                                "/api/template\" "
                                "-d"
                                "\"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\t'{{state.attributes.friendly_name}}'\\n{% endfor %}\\\"}\""))))
      (split-string entity_ids "\n"))))

(defun hass-api/refresh-entities-and-names()
  "Download latest entities from Home Assistant"
  (interactive)
  (setq hass-api/entities-and-names (hass-api/get-all-entities-and-names-as-list)))

(hass-api/refresh-entities-and-names)
(spacemacs/set-leader-keys "ahrn" 'hass-api/refresh-entities-and-names)

;; (defun hass-api/get-all-services-as-list())

(defun hass-api/gitpull-restart()
  "Restart the hassio Git Pull addon"
  (interactive)
  (save-excursion
    (let* ((curl-command (concat "curl \"-i\" \"-H\" \"Content-Type: application/json\" \"-H\" \"Authorization: Bearer "
                                hass-api/token
                                "\" \"-XPOST\" \""
                                hass-api/url
                                "/api/services/hassio/addon_restart\" "
                                "\"-d\" \"{\\\"addon\\\":\\\"core_git_pull\\\"}\"")))
      (async-shell-command curl-command "*hassio*" "*httperror*")
      )
    )
  )

(defun hass-api/get-all-entities()
  "Get all Entity Id's from Home Assistant"
  (interactive)
  (save-excursion
    (when (hass-api/connection-check)
      (let* ((curl-command (concat "curl -H \"Content-Type: application/json\" "
                                   " -H \"Authorization: Bearer "
                                   hass-api/token
                                   "\" \"-XPOST\" \""
                                   hass-api/url
                                   "/api/template\" "
                                   "\"-d\" \"{\\\"template\\\":\\\"{% for state in states %}{{state.entity_id}}\\n{% endfor %}\\\"}\"")))
        (async-shell-command curl-command "*hassio*" "*httperror*")))))

(defun hass-api/get-state-by-entity(&optional entity_id)
  "Get the state properties of the entity provided"
  (interactive)
  (save-excursion
    (when (= 0 (call-process "ping" nil nil nil "-c" "1" "-W" "1"
                             (replace-regexp-in-string
                              "^https?:\\/\\/" "" hass-api/url nil)))
      (let* ((entity_id (or entity_id (hass-api/get-entity-from-list)))
             (curl-command (concat "curl -H \"Content-Type: application/json\" "
                                   "-H \"Authorization: Bearer "
                                   hass-api/token
                                   "\" -X GET "
                                   hass-api/url
                                   "/api/states/"
                                   entity_id)))
        (async-shell-command curl-command "*hassio*" "*httperror*")
        (message "Entities obtained")
        (switch-to-buffer-other-window "*hassio*")
        (evil-escape)
        ;; (with-current-buffer "*hassio*"
        ;;   (json-mode))
        ;; ;; (json-mode-beautify)
        ))))

(spacemacs/set-leader-keys "ahE" 'hass-api/get-state-by-entity)

(defun hass-api/get-entity-from-list()
  "Get the state properties of the entity provided"
  (save-excursion
    (let* ((entity_id (helm :sources
                             (helm-build-sync-source "HA Entities"
                               :candidates hass-api/entities-and-names
                               :fuzzy-match t))))
      (car (split-string entity_id "\t")))))


;; (hass-api/get-entity-from-list)
(defun hass-api/get-entity-from-list-to-buffer()
  "Output selected entity id from a helm list of entities"
  (interactive)
  (save-excursion
    (let* ((entity_id (hass-api/get-entity-from-list)))
      (forward-char)
      (insert entity_id))))

(spacemacs/set-leader-keys "ahe" 'hass-api/get-entity-from-list-to-buffer)

(defun hass-api/get-state-from-list()
  "Get entity state from a helm list of entities"
  (interactive)
  (let* ((entity_id (hass-api/get-entity-from-list))
         (template_statement
          (concat "\"{\\\"template\\\":\\\""
                  "{{ states." entity_id
                  " }}"
                  "\\\"}\"")
          ))
    (message "%s" (shell-command-to-string
                   (concat "curl -s -H \"Content-Type: application/json\" "
                           "-H \"Authorization: Bearer "
                           hass-api/token
                           "\" "
                           hass-api/url
                           "/api/template "
                           "-d"
                           template_statement)))))
(spacemacs/set-leader-keys "ahs" 'hass-api/get-state-from-list)

(defun hass-api/template(arg)
  "Run supplied template as `arg' on Home Assistant instance"
  (interactive "sTemplate: ")
  (let* ((arg (concat "{\\\"template\\\":\\\"" arg "\\\"}")))
    (unless arg
      (error "No temlate provided"))
    (async-shell-command
     (concat "curl -s -H \"Content-Type: application/json\" "
             "-H \"Authorization: Bearer "
             hass-api/token
             "\" "
             hass-api/url
             "/api/template "
             "-d \"" arg "\"")
     "*HA Template*"
     "*HA Error*")
    (message "Template: %s" arg)))

(defun hass-api/json-to-alist(jsonString)
  "Convert a json object to an alist"
  (let ((json-object-type 'alist)
        (json-array-type 'list)
        (outList ""))
    (setq outList (json-read-from-string jsonString))
    outList))

(defun hass-api/get-all-services-and-names-as-list()
  "Use curl to grab a list of all services and their friendly names from home assistant"
  (let* ((serviceJson (shell-command-to-string
                       (concat "curl -s -H \"Content-Type: application/json\" "
                               "-H \"Authorization: Bearer "
                               hass-api/token
                               "\" \""
                               hass-api/url
                               "/api/services\" ")))
         (serviceList (hass-api/json-to-alist serviceJson))
         outList)
    (dolist (domains serviceList)
      (let ((domain (alist-get 'domain domains))
            (services (mapcar 'car (alist-get 'services domains))))
        (dolist (service services)
          (setq outList (cons (concat domain "." (format "%s" service)) outList)))))
    outList))

(defun hass-api/refresh-services-and-names()
  "Download latest services from Home Assistant"
  (interactive)
  (setq hass-api/services-and-names (hass-api/get-all-services-and-names-as-list)))
(hass-api/refresh-services-and-names)
(spacemacs/set-leader-keys "ahrs" 'hass-api/refresh-services-and-names)

(defun hass-api/get-services-from-list()
  "Get the services from the home assistant api"
  (save-excursion
    (let* ((service_id (helm :sources
                            (helm-build-sync-source "HA Services"
                              :candidates hass-api/services-and-names
                              :fuzzy-match t))))
      (car (split-string service_id "\t")))))

(defun hass-api/get-services-from-list-to-buffer()
  "Output selected services id from a helm list of entities"
  (interactive)
  (save-excursion
    (let* ((services_id (hass-api/get-services-from-list)))
      (forward-char)
      (insert services_id))))

(spacemacs/set-leader-keys "ahs" 'hass-api/get-services-from-list-to-buffer)

(defun mjp/browse-url-hassio()
  "Browse to the hassio url specified in hass-token.txt"
  (interactive)
  (browse-url hass-api/url)
  (message "%s" hass-api/url))
(spacemacs/set-leader-keys "ahh" 'mjp/browse-url-hassio)

(spacemacs|define-custom-layout "eulerremote"
  :binding "e"
  :body
  (let ((sshConfig (if (= 0 (call-process "ping" nil nil nil "192.168.40.139" "-c" "1" "-W" "1")) "eulerlocal" "eulerremote")))
    (message "connecting to %s" sshConfig)
    (find-file (concat "/scp:" sshConfig ":/config/"))
    (magit-status)))

(provide 'hass-api)
