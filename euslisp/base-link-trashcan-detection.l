;;#!/usr/bin/env roseus

;; mainly copied from jsk_demos/201910semi

(ros::roseus "trashcan-detection")
;;load packages
(load "package://fetcheus/fetch-interface.l")
;;(load "package://pr2eus_moveit/euslisp/collision-object-publisher.l")
;;(load "package://jsk_fetch_startup/euslisp/navigation-utils.l")

(ros::load-ros-manifest "jsk_recognition_msgs")

;;defvarは一度やってしまったら上書きされない
(defvar *topic-name* "/pcl_nodelet/boxes_trashcanedge")
(defvar *gift-name* "/atohayoroshiku")
(defvar *bounding-box-list* nil)
(defvar *gift-number* nil)

;; (fetch-init)
;; (objects (list *fetch*))

(setq time-stamp (ros::time 0))

;;callback
(defun bounding-box-array-cb (msg)
  ;;(ros::ros-info "cb called")
  (setq *bounding-box-list* (send msg :boxes)) ;; boxesは、BoundingBoxのArray(Euslispではlist)
  ;;(ros::ros-info "set box-list")
  (when *bounding-box-list*
    (let* ((b (elt *bounding-box-list* 0))
           (base->obj-coords (ros::tf-pose->coords (send b :pose)))
           (base-coords (send (send *fetch* :base_link_lk) :copy-worldcoords)))
      (when (ros::time> time-stamp (send msg :header :stamp)) ;;rostime揃え
        (return-from bounding-box-array-cb nil))
      (ros::ros-info "tf")
      (setq obj-pos (scale 0.001
                           (send (send base-coords :transform base->obj-coords) :worldpos)))
      (setq found-obj t)
      (print obj-pos)
      obj-pos)))

(defun grasp-with-rec (obj-pos)
  (setq target-cds (make-coords :pos (scale 1000 obj-pos)))
  (ros::ros-info "targe-cds 1")
  (ros::ros-info (format nil "~A" target-cds))
  (send target-cds :translate #f(-200 0 50)) ;;z should be 0, but the link is not rigid in gazebo, so 100 is the height offset for end effector.
  (ros::ros-info "targe-cds 2")
  (ros::ros-info (format nil "~A" target-cds))
  (objects (list *fetch* target-cds))

  (send *fetch* :inverse-kinematics target-cds)
  (ros::ros-warn "the grap arm pose is ~A" (send *fetch* :angle-vector))
  (send *ri* :angle-vector  (send *fetch* :angle-vector) 3000)
  (send *ri* :wait-interpolation)

  (send *fetch* :inverse-kinematics (send target-cds :translate #f(200 0 0)) :rotation-axis :y)
  (send *ri* :angle-vector  (send *fetch* :angle-vector) 3000)
  (send *ri* :wait-interpolation))


(defun look-at-coord (coord &optional (tm 3000) (wi nil))
    (send *fetch* :head :look-at (send coord :worldpos))
    (send *ri* :angle-vector (send *fetch* :angle-vector) tm)
    (send *ri* :wait-interpolation wi))

(defun main()
  (ros::subscribe *topic-name* jsk_recognition_msgs::BoundingBoxArray #'bounding-box-array-cb 1)
  )

(defun trashcan-grasp (obj-pos)
  (let ((cam-coords nil)
        (obj-coords (make-coords :pos (scale 1000 obj-pos) :rpy #f(0 0 0))))
    (unless (boundp '*tfl*) (setq *tfl* (instance transform-listener :init)))
    (setq cam-coords
          (send *tfl* :lookup-transform "/base_link" "/head_camera_depth_optical_frame" (ros::time 0)))
    (send *fetch* :angle-vector #f(20.0 56.549 86.0026 -30.9913 101.496 -91.683 92.782 8.07181 0.0 0.0))
    ;; (send *fetch* :rarm :inverse-kinematics (make-coords :pos #f(400 -200 500) :rpy (float-vector 0 0 pi/2)))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)
    (send obj-coords :transform cam-coords :world)
    (send obj-coords :transform (make-coords :pos #f(0 0 100)) :world)
    (send *fetch* :head :neck-y :joint-angle -90)
    (send *fetch* :head :neck-p :joint-angle 60)
    (send *ri* :angle-vector-raw (send *fetch* :angle-vector) :head-controller)
    (send *ri* :wait-interpolation)
    (send *fetch*
          :rarm :inverse-kinematics
          (make-coords :pos (send obj-coords :pos) :rpy (float-vector 0 pi/2 pi/2)) :rotation-axis t)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000) ;; reaching
    (send *ri* :wait-interpolation)
    (send *fetch* :rarm :move-end-pos #f(100 0 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000)
    (send *ri* :wait-interpolation)
    (send *fetch* :start-grasp)
    (send *ri* :start-grasp)
    (unix::sleep 1)

    ;; TODO
    ;; trashcan-inside-detection
    (setq watching-coords
          (make-coords
           :pos (float-vector (- (elt (send obj-coords :pos) 0)
                                 (* (sin (/ pi/2 2)) (elt (send obj-coords :pos) 2)))
                              (elt (send obj-coords :pos) 1)
                              (* (cos (/ pi/2 2)) (elt (send obj-coords :pos) 2)))
           :rpy (float-vector 0 (/ pi/2 2) pi/2)))
    (send *fetch* :rarm :inverse-kinematics watching-coords :rotation-axis t)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)
    ;; (send *fetch* :rarm :inverse-kinematics (make-coords :pos #f(400 -200 400) :rpy (float-vector 0 (/ pi/2 2) pi/2)))
    ;; #f(20.0 12.7397 58.0108 -63.9436 127.969 -161.961 123.759 -5.36722 0.0 0.0)

    (send *fetch* :move-end-pos #f(0 0 100))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)
    (send *fetch* :stop-grasp)
    (send *ri* :stop-grasp)
    (unix::sleep 1)
    (send *fetch* :reset-pose)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)))

(defun right-side(obj-pos)
  (let ((cam-coords nil)
        (obj-coords nil))
    (unless (boundp '*tfl*) (setq *tfl* (instance transform-listener :init)))
    (setq cam-coords
          (send *tfl* :lookup-transform "/base_link" "/head_camera_depth_optical_frame" (ros::time 0)))
    (unix::sleep 2)
    ;; (send *fetch* :angle-vector #f(20.0 56.549 86.0026 -30.9913 101.496 -91.683 92.782 8.07181 0.0 0.0)) ;; (send *fetch* :rarm :inverse-kinematics (make-coords :pos #f(400 -200 500) :rpy (float-vector 0 0 pi/2)))
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    ;; (send *ri* :wait-interpolation)
    (setq obj-coords (make-coords :pos (scale 1000 obj-pos) :rpy #f(0 0 0)))
    (send obj-coords :transform cam-coords :world)
    (send obj-coords :transform (make-coords :pos #f(0 0 100)) :world)
    (ros::ros-info "~A" obj-coords)
    (send *fetch* :head :neck-y :joint-angle -90)
    (send *fetch* :head :neck-p :joint-angle 60)
    (send *ri* :angle-vector-raw (send *fetch* :angle-vector) 3000 :head-controller)
    (send *ri* :wait-interpolation)
    (send *fetch* :rarm :inverse-kinematics
          (make-coords :pos (send obj-coords :pos) :rpy (float-vector 0 pi/2 0)) :rotation-axis t)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000) ;; reaching
    (send *ri* :wait-interpolation)
    (send *fetch* :rarm :move-end-pos #f(100 0 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000 :use-torso nil)
    (send *ri* :wait-interpolation)
    ;; (send *fetch* :start-grasp)
    ;; (send *ri* :start-grasp)
    (unix::sleep 1)
    (send *fetch* :rarm :move-end-rot -45 :z)
    (send *fetch* :rarm :move-end-pos #f(0 150 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000 :use-torso nil)
    (send *ri* :wait-interpolation)
    (send *ri* :speak-jp "ごみ箱の中身を確認します")
    (unix::sleep 2)

    (send *fetch* :rarm :move-end-pos #f(0 -150 0))
    (send *fetch* :rarm :move-end-rot 45 :z)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000 :use-torso nil)
    (send *ri* :wait-interpolation)

    (send *fetch* :rarm :move-end-pos #f(-100 0 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)
    (send *fetch* :reset-pose)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000)
    (send *ri* :wait-interpolation)
    ))

(defun rope(obj-pos)
  (let ((cam-coords nil)
        (obj-coords nil))
    (ros::spin-once)
    (unless (boundp '*tfl*) (setq *tfl* (instance transform-listener :init)))
    (setq cam-coords (send *tfl*
                           :lookup-transform "/base_link" "/head_camera_depth_optical_frame"
                           (ros::time 0)))
    (unix::sleep 2)
    ;; (send *fetch* :angle-vector #f(20.0 56.549 86.0026 -30.9913 101.496 -91.683 92.782 8.07181 0.0 0.0)) ;; (send *fetch* :rarm :inverse-kinematics (make-coords :pos #f(400 -200 500) :rpy (float-vector 0 0 pi/2)))
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    ;; (send *ri* :wait-interpolation)
    (setq obj-coords (make-coords :pos (scale 1000 obj-pos) :rpy #f(0 0 0)))
    (send obj-coords :transform cam-coords :world)
    (send obj-coords :transform (make-coords :pos #f(0 50 0)) :world)
    (ros::ros-info "~A" obj-coords)

    (send *fetch* :rarm :inverse-kinematics obj-coords :rotation-axis t)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000) ;; reaching
    (send *ri* :wait-interpolation)
    (send *fetch* :rarm :move-end-pos #f(70 0 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000 :use-torso nil)
    (send *ri* :wait-interpolation)
    (send *ri* :start-grasp)
    (send *ri* :speak-jp "ごみ袋を持ち上げます" :wait t)

    (send obj-coords :transform (make-coords :pos #f(-50 0 1300)) :world)
    (send *fetch* :rarm :inverse-kinematics obj-coords :rotation-axis nil)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000 :use-torso t)
    (send *ri* :wait-interpolation)
    (send *fetch* :torso :waist-z :joint-angle 360)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000)
    (send *ri* :wait-interpolation)

    (send *ri* :go-pos-unsafe 0 0 -90)
    (send *fetch* :torso :waist-z :joint-angle 0)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    (send *ri* :wait-interpolation)
    ))

(defun hole(obj-pos)
  (let ((cam-coords nil)
        (obj-coords nil))
    (ros::spin-once)
    (unless (boundp '*tfl*) (setq *tfl* (instance transform-listener :init)))
    (setq cam-coords (send *tfl*
                           :lookup-transform "/base_link" "/head_camera_depth_optical_frame"
                           (ros::time 0)))
    (unix::sleep 2)
    ;; (send *fetch* :angle-vector #f(20.0 56.549 86.0026 -30.9913 101.496 -91.683 92.782 8.07181 0.0 0.0)) ;; (send *fetch* :rarm :inverse-kinematics (make-coords :pos #f(400 -200 500) :rpy (float-vector 0 0 pi/2)))
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    ;; (send *ri* :wait-interpolation)
    (setq obj-coords (make-coords :pos (scale 1000 obj-pos) :rpy (float-vector 0 0 pi/2)))
    (send obj-coords :transform cam-coords :world)
    (send obj-coords :transform (make-coords :pos #f(-130 -25 30)) :world)
    (setq obj-coords (make-coords :pos (send obj-coords :pos) :rpy (float-vector 0 0 pi/2)))
    (ros::ros-info "~A" obj-coords)

    (send *fetch* :rarm :inverse-kinematics obj-coords :rotation-axis t)
    (send *ri* :angle-vector (send *fetch* :angle-vector) 10000) ;; reaching
    (send *ri* :wait-interpolation)
    (send *fetch* :rarm :move-end-pos #f(70 0 0))
    (send *ri* :angle-vector (send *fetch* :angle-vector) 4000 :use-torso nil)
    (send *ri* :wait-interpolation)
    (send *ri* :start-grasp)
    (send *ri* :speak-jp "ごみ袋を持ち上げます" :wait t)

    ;; (send obj-coords :transform (make-coords :pos #f(-50 0 1300)) :world)
    ;; (send *fetch* :rarm :inverse-kinematics obj-coords :rotation-axis nil)
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 5000 :use-torso t)
    ;; (send *ri* :wait-interpolation)
    ;; (send *fetch* :torso :waist-z :joint-angle 360)
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 10000)
    ;; (send *ri* :wait-interpolation)

    ;; (send *ri* :go-pos-unsafe 0 0 -90)
    ;; (send *fetch* :torso :waist-z :joint-angle 0)
    ;; (send *ri* :angle-vector (send *fetch* :angle-vector) 5000)
    ;; (send *ri* :wait-interpolation)
    ))
