#!/usr/bin/env roseus

;; load robot and scene model
(require "package://fetcheus/fetch-utils.l")
(require "package://fetcheus/fetch-interface.l")
(require "package://jsk_maps/src/eng2-scene.l")

(unless (boundp '*scene*)
  (setq *scene* (make-eng2-2f-scene)))
(unless (boundp '*ri*)
  (fetch-init)) ;; fetch-init instantiate *fetch* and *ri*

;; show in irtviewer
(objects (list *fetch* *scene*))
;; show in "fetch Kinematics Simulator"
(send *ri* :objects (send *scene* :objects))

;; ;; use (mapcar #'(lambda (x) (send x :name)) (send *scene* :spots)) to get list of spots
;; (send *fetch* :move-to (send *scene* :spot "/eng2/7f/room73B2-fetch-dock-front") :world)

;; ;; check 20201026-soft3-model, the code to focus on the robot model
;; (send *irtviewer* :look-all
;;       (send (geo::make-bounding-box
;;              (flatten (send-all (send *fetch* :bodies) :vertices)))
;;             :grow 2.0))
