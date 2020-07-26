;;; cs-org-images.el --- functionality to have a reasonable image-handling workflow in org-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  chris

;; Author: chris <chris@chris-thinkpad>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'org)

(defun link-path-at-point ()
  (interactive)
  (let* ((link-type (org-element-property :path (org-element-context))))
    link-type))

(defun ll/org/link-file-path-at-point ()
   (link-path-at-point))

(defvar ll/org/insert-screenshot/redisplay-images t
  "Redisplay images after inserting a screenshot with
`ll/org/insert-screenshot'?")

(defun ll/org/insert-screenshot (&optional arg)
  "Capture a screenshot and insert a link to it in the current
buffer. If `ll/org/insert-screenshot/redisplay-images' is non-nil,
redisplay images in the current buffer.

By default saves images to ./resources/screen_%Y%m%d_%H%M%S.png,
creating the resources directory if necessary.

With a prefix arg (C-u) prompt for a filename instead of using the default.

Depends upon `import` from ImageMagick."
  (interactive)
  (unless (or arg
              (file-directory-p "./resources"))
    (make-directory "resources"))
  (let* ((default-dest
           (format-time-string "./resources/screen_%Y%m%d_%H%M%S.png"))
         (dest (if arg
                   (helm-read-string "Save to: " default-dest)
                 default-dest)))
    (start-process "import" nil "/usr/bin/import" dest)
    (read-char "Taking screenshot... Press any key when done.")
    (org-insert-link t (concat "file:" dest) "")
    (when ll/org/insert-screenshot/redisplay-images
      (org-remove-inline-images)
      (org-display-inline-images))))


(defvar ll/org/edit-image/redisplay-images t
  "Redisplay images after editing an image with `ll/org/edit-image'?")

(defun ll/org/edit-image (&optional arg)
  "Edit the image linked at point. If
`ll/org/insert-screenshot/redisplay-images' is non-nil, redisplay
images in the current buffer."
  (interactive)
  (let ((img (ll/org/link-file-path-at-point)))
    (start-process "gimp" nil "/usr/bin/gimp" img)
    (read-char "Editing image... Press any key when done.")
    (when ll/org/edit-image/redisplay-images
      (org-remove-inline-images)
      (org-display-inline-images))))

(defun ll/org/resize-image-at-point (&optional arg)
  "Resize the image linked at point. If
`ll/org/insert-screenshot/redisplay-images' is non-nil, redisplay
images in the current buffer."
  (interactive)
  (let ((img (ll/org/link-file-path-at-point))
        (percent (read-number "Resize to what percentage of current size? ")))
    (start-process "mogrify" nil "/usr/bin/mogrify"
                   "-resize"
                   (format "%s%%" percent)
                   img)
    (when ll/org/edit-image/redisplay-images
      (org-remove-inline-images)
      (org-display-inline-images))))



;; --- just insert a picture on the clipboard ---
(defun cs-paste-image-into-org ()
  "TODO:
- create directory for org file with `pasted` assets
- move the temporary file into that assets directory
  and name it by an md5sum string in the filename
- link to the image"
  (interactive)

  (let* ((targets-str (shell-command-to-string "xclip -selection clipboard -t TARGETS -o"))
         (png-target-available (when (string-match "image/png" targets-str) t))
         (tmp-target-filename (concat "pasted_"
                                      (cs-get-random-string 30)
                                      ".png"))
         (tmp-target-filepath (concat (file-name-as-directory
                                       temporary-file-directory)
                                      tmp-target-filename))
         ;; target-filename
         target-filepath)

    ;; --- check if xclip has a image/png target ---
    (if png-target-available
        (let* ()
          (shell-command-to-string (concat "xclip -selection clipboard -t image/png -o > "
                                           tmp-target-filepath))
          (if (file-exists-p tmp-target-filepath)
              (let* ((assets-dir-path (get-assets-dir-from-org-file (buffer-file-name))))

                ;; --- copy the image into the assets directory ---
                ;; -- make the assets directory --
                (when (not (file-exists-p assets-dir-path))
                  (when (yes-or-no-p (concat "Create the assets directory "
                                             assets-dir-path
                                             " ? "))
                    (make-directory assets-dir-path t)))

                (copy-file tmp-target-filepath
                           (setq target-filepath
                                 (concat (file-name-as-directory assets-dir-path)
                                         (let* ((md5sum-output-str
                                                 (shell-command-to-string
                                                  (concat "md5sum " tmp-target-filepath)))
                                                matched-md5-str)
                                           (string-match "\\(^[0-9A-Za-z]+\\)" md5sum-output-str)
                                           (setq matched-md5-str
                                                 (match-string-no-properties 1 md5sum-output-str))
                                           (concat "pasted_" matched-md5-str ".png")))))
                (save-excursion
                  (insert "[[file:"
                          (concat "./" (file-relative-name target-filepath
                                                           (file-name-directory (buffer-file-name))))
                          "]]")
                  (org-display-inline-images)
                  (org-redisplay-inline-images)))
            (user-error (concat "Tmp file " tmp-target-filepath
                                " does not exist"))))
      (user-error "No png target available"))))

(provide 'cs-org-images)
;;; cs-org-images.el ends here
