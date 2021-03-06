#!/usr/bin/env roseus
;; "high-touch" with Fetch!

(ros::roseus "high-five")
(ros::load-ros-manifest "jsk_recognition_msgs")

(setq f 0)

(defun search-mark (frame)
  (setq *mark* nil)
  (ros::rate 10)
  (while (null *mark*)
    (unless (boundp '*tfl*) (setq *tfl* (instance transform-listener :init)))
    ;; (setq tm (send *tfl* :get-latest-common-time "/base_link" frame))
    (setq *mark* (send *tfl* :lookup-transform "/base_link" frame (ros::time 0)))
    ;;(ros::ros-info "msg [~A]" *mark*)
    (ros::sleep)
    )
  (ros::ros-info "msg [~A]" *mark*)
  ;; (setq c1 (make-cube 100 100 1000))
  ;; (send c1 :move-to (send (send *fetch* :copy-worldcoords) :transform mark) :world)
  ;; (objects (list *fetch* *scene* c1))
  *mark*)

;; (initialize) relative-move-hand 300 -400 1000 0 -pi/2 0
(defun high-five (coord)
  (setq tmp-endpos (send (send *fetch* :copy-worldcoords) :transform (send (send (send coord :copy-worldcoords) :translate #f(0 0 0) :world) :rotate pi/2 :z)))
  
  ;; (setq y-endpos (elt (send tmp-endpos :worldpos) 1))
  ;; (setq z-endpos (elt (send tmp-endpos :worldpos) 2))
  
  ;; (setq *endpos* (v- xyz-endpos (float-vector 0 0 (+ (elt xyz-endpos 2))))
  (ik-coord *endpos*)
  )

  

(defun whole-high-five-partly (a)
  (search-mark "/sample1")
  (high-five *endpos*)
  ;; (cond ((string= a "suica") (touch-ic-desk-1 *mark*))
  ;;       ((string= a "paypay") (show-qrcode *mark*))
  ;;       )
  ;; ;;(send *fetch* :rarm :move-end-pos #f(0 0 -10))
  ;; ;;(send *ri* :angle-vector (send *fetch* :angle-vector))
  )

(defun voice-action ()
  (setq f 0)
  (ros::ros-info "init!")
  (while (= f 0)
    (ros::ros-info "done!")
    (setq message (one-shot-subscribe "/speech_to_text_google" speech_recognition_msgs::SpeechRecognitionCandidates))
    (setq message (elt (send message :transcript) 0))
    (print message)
    (cond ((string= message "ハイタッチ") (setq f 1))
          ((or (string= message "ペイペイ") (string= message "台北") (string= message "paypay")) (setq f 2))
          ((string= message "終わり") (setq f 3))
          ((string= message "渡しました") (setq f 4)))
    )
  f)



(defun end-movement ()
  (send *fetch* :rarm :move-end-pos #f(0 100 0))
  (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
  ;;(send *ri* :go-pos -0.5 0 0)
  (relative-move-hand 600 -300 900 0 0 pi/2)
  (reset-pose))

;; (defun touch-cycle ()
;;   (let (end_tag)
;;     (setq end_tag 1)
;;     (relative-move-hand 600 -300 900 0 0 pi/2)
;;     ;;(look-down 30)
;;     (unix::sleep 1)
;;     (hold-suica)
;;     (while (and (ros::ok) (= end_tag 1))
;;       (voice-action)
;;       (cond ((= f 1) (progn (send *ri* :speak-jp "すいかでしはらいます") (whole-touch-desk-partly "suica")))
;;             ((= f 2) (progn (send *ri* :speak-jp "ぺいぺい") (whole-touch-desk-partly "paypay")))
;;             ((= f 3) (progn (setq end_tag 0) (send *ri* :speak-jp "おわります") (end-movement)))
;;             )
;;       )
;;     )
;;   )
