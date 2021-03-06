(load "package://jsk_robot_startup/lifelog/tweet_client.l")
(load "package://jsk_maps/src/change-floor.l")

(ros::load-ros-manifest "fetch_auto_dock_msgs")
(ros::load-ros-manifest "jsk_robot_startup")
(ros::load-ros-manifest "power_msgs")

(defparameter *dock-action* nil)
(defparameter *undock-action* nil)
(defparameter *spots* nil)
(defparameter *tfl* (instance ros::transform-listener :init))


(let ((robot-name (ros::get-param "/robot/name")))
  (defparameter *dock-spot*
    (cond
      ((equal robot-name "fetch15")
       "/eng2/7f/room73B2-fetch-dock-front")
      ((equal robot-name "fetch1075")
       "/eng2/7f/room73B2-fetch-dock2-front")
      (t nil))))


(defun get-spot-coords (name)
  (unless *spots*
    (setq *spots* (one-shot-subscribe "/spots_marker_array" visualization_msgs::MarkerArray)))
  (let ((spot-coords nil) (frame-id nil))
    (dolist (x (send *spots* :markers))
      (if (equal (send x :text) name)
        (progn
          (setq spot-coords (send x :pose))
          (setq frame-id (send (send x :header) :frame_id)))))
    (send (send spot-coords :position) :z 0)
    (setq spot-coords (ros::tf-pose->coords spot-coords))
    (cons spot-coords frame-id)))

(defun simple-dock (&key (use-pose t))
  (unless *dock-action*
    (setq *dock-action*
          (instance ros::simple-action-client :init
                    "/dock" fetch_auto_dock_msgs::DockAction)))
  (unless (send *dock-action* :wait-for-server 5)
    (ros::ros-error "/dock action server is not started")
    (return-from dock nil))
  (let ((dock-action-goal (instance fetch_auto_dock_msgs::DockActionGoal :init)))
    (when use-pose
      (let* ((timestamp (ros::time-now))
             (cret (get-spot-coords *dock-spot*))
             (frame-to-dock (car cret))
             (frame-id (cdr cret))
             (lret (send *tfl* :wait-for-transform "base_link" frame-id timestamp 5))
             (base-to-frame (send *tfl* :lookup-transform "base_link" frame-id timestamp))
             (goal-pose (ros::coords->tf-pose (send frame-to-dock :transform base-to-frame :world)))
             (pose-msg (instance geometry_msgs::PoseStamped :init)))
        (send pose-msg :header :stamp timestamp)
        (send pose-msg :header :frame_id "base_link")
        (send pose-msg :pose goal-pose)
        (send dock-action-goal :goal :dock_pose pose-msg)))
    (send *dock-action* :send-goal dock-action-goal)
    (unless (send *dock-action* :wait-for-result :timeout 60)
      (send *dock-action* :cancel-all-goals)
      (ros::ros-error "No result returned from /dock action server")
      (return-from simple-dock nil))
    (send (send *dock-action* :get-result) :docked)))

(defun dock ()
  ;; look down
  (unless (boundp '*ri*)
    (require :fetch-interface "package://fetcheus/fetch-interface.l")
    (fetch-init))
  (send *fetch* :angle-vector (send *ri* :state :potentio-vector))
  (send *fetch* :head :look-at (float-vector 800 0 500))
  (send *ri* :angle-vector (send *fetch* :angle-vector) 1000)
  (send *ri* :wait-interpolation)
  (simple-dock))

(defun undock ()
  (unless *undock-action*
    (setq *undock-action*
          (instance ros::simple-action-client :init
                    "/undock" fetch_auto_dock_msgs::UndockAction)))
  (unless (send *undock-action* :wait-for-server 5)
    (ros::ros-error "/undock action server is not started")
    (return-from undock nil))

  (send *undock-action* :send-goal
        (instance fetch_auto_dock_msgs::UndockActionGoal :init))
  (unless (send *undock-action* :wait-for-result :timeout 60)
    (ros::ros-error "No result returned from /undock action server")
    (return-from undock nil))
  (send (send *undock-action* :get-result) :undocked))

(defun go-to-spot (name &optional (relative-coords (make-coords)) &key (undock-rotate nil))
  ;; undock if fetch is docking
  (unless (boundp '*ri*)
    (require :fetch-interface "package://fetcheus/fetch-interface.l")
    (fetch-init))
  (let ((undock-success nil))
    (block go-to-spot-undock
      (dotimes (i 3)
        (let* ((msg (one-shot-subscribe "/battery_state" power_msgs::batterystate :timeout 1500))
               (is-charging (send msg :is_charging)))
          ;; You may fail to subscribe /battery_state
          ;; because of message md5 difference between melodic and indigo.
          (unless msg
            (ros::ros-warn "Failed to subscribe /battery_state")
            (ros::ros-warn "Skip undocking, so please make sure that Fetch is already undocked.")
            (return-from go-to-spot-undock t))
          (if is-charging
            (progn
              (setq undock-success (auto-undock :n-trial 3))
              ;; rotate after undock
              (if (and undock-success undock-rotate)
                (send *ri* :go-pos-unsafe 0 0 180)))
            (return-from go-to-spot-undock t))
          (if (not undock-success)
            (progn
              (ros::ros-error "Failed to undock")
	      (send *ri* :speak "I failed to undock.")))))
      (if (not undock-success) (return-from go-to-spot nil))))
  ;; go to spot
  (let* ((ret (get-spot-coords name))
         (goal-pose (car ret))
         (frame-id (cdr ret)))

    (when relative-coords
      (setq goal-pose (send goal-pose :transform relative-coords :world)))
    (send *ri* :clear-costmap)
    (send *ri* :move-to goal-pose :frame-id frame-id)))

(defun auto-dock (&key (n-trial 1))
  (let ((success nil))
    (dotimes (i n-trial)
      (when (go-to-spot *dock-spot* (make-coords :pos #f(-800 0 0)))
        (ros::ros-info "arrived at the dock.")
        (setq success (dock))
        (when success (return-from auto-dock success))))
    success))

(defun auto-undock (&key (n-trial 1))
  (let ((success nil))
    (unless (boundp '*ri*)
      (require :fetch-interface "package://fetcheus/fetch-interface.l")
      (fetch-init))
    (dotimes (i n-trial)
      (ros::ros-info "trying to do undock.")
      (setq success (undock))
      (when success (return-from auto-undock success)))
    (if (not success)
      (let ((enable-request (instance power_msgs::BreakerCommandRequest :init :enable t))
            (disable-request (instance power_msgs::BreakerCommandRequest :init :enable nil))
            (breaker-service-name "base_breaker"))
        (ros::wait-for-service breaker-service-name 5)
        (ros::service-call breaker-service-name disable-request)
        (ros::ros-error "Diable base breaker")
        (send *ri* :speak "I disable and enable base breaker.")
        (unix::sleep 5)
        (ros::service-call breaker-service-name enable-request)
        (ros::ros-error "Enable base breaker")))
    success))

(defun go-to-kitchen (&key (tweet t) (n-dock-trial 1) (n-kitchen-trial 1))
  ;; go to kitchen
  (unless (boundp '*ri*)
    (require :fetch-interface "package://fetcheus/fetch-interface.l")
    (fetch-init))
  (ros::ros-info "start going to the kitchen.")
  (send *ri* :speak-jp "キッチンに向かいます。" :wait t)
  (unix::sleep 1)
  ;; Check if the lights are on in the room
  (let* ((room-light-msg (one-shot-subscribe "/check_room_light/output" jsk_robot_startup::RoomLight))
         (initial-light-on (if room-light-msg (send room-light-msg :light_on)))
         (success-go-to-kitchen nil)
         (success-auto-dock nil))
    (if initial-light-on
      (send *ri* :speak-jp "すでに電気がついています。" :wait t)
      (progn
        ;; The accuracy of Google Home recognition is better in English than in Japanese.
        ;; (send *ri* :speak-jp "オッケー、グーグル" :wait t)
        ;; (send *ri* :speak-jp "電気をつけて" :wait t)
        (send *ri* :speak "OK, Google" :wait t)
        (send *ri* :speak "Turn on the light." :wait t)))
    (unix::sleep 1)
    ;; stove
    (dotimes (i n-kitchen-trial)
      (setq success-go-to-kitchen
            (go-to-spot "/eng2/7f/room73B2-sink-front0"
                        (make-coords :pos #f(400 -500 0)) :undock-rotate t))
      (when success-go-to-kitchen (return)))
    (if success-go-to-kitchen
      (progn ;; succeeded to go to kitchen
        (unix:sleep 1)
        (ros::ros-info "arrived at the kitchen stove.")
        (send *ri* :speak-jp "キッチンのコンロの前につきました。" :wait t)
        (unix:sleep 1)
        ;; stove
        (when tweet
          (tweet-string "I took a photo at 73B2 Kitchen stove." :warning-time 3
                        :with-image "/edgetpu_object_detector/output/image" :speak t))
        (send *ri* :go-pos-unsafe 0 0 -45)
        ;; sink
        (when tweet
          (tweet-string "I took a photo at 73B2 Kitchen sink." :warning-time 3
                        :with-image "/edgetpu_object_detector/output/image" :speak t))
        (send *ri* :go-pos-unsafe 0 0 135))
      (progn ;; failed to go to kitchen
        (ros::ros-error "failed going to the kitchen.")
        (send *ri* :speak-jp "失敗しました。" :wait t)))
    ;; sink
    ;; (send *ri* :speak-jp "シンクに向かいます。")
    ;; (if (go-to-spot "/eng2/7f/room73B2-sink-front1" (make-coords :pos #f(100 -200 0)))
    ;;   (progn ;; succeeded to go to kitchen
    ;;     (unix:sleep 1)
    ;;     (ros::ros-info "arrived at the kitchen.")
    ;;     (send *ri* :speak-jp "キッチンのシンクの前につきました。" :wait t)
    ;;     (unix:sleep 1)
    ;;     (when tweet
    ;;       (tweet-string "I took a photo at 73B2 Kitchen sink." :warning-time 3
    ;;                     :with-image "/edgetpu_object_detector/output/image" :speak t)))
    ;;   (progn ;; failed to go to kitchen
    ;;     (ros::ros-error "failed going to the kitchen.")
    ;;     (send *ri* :speak-jp "失敗しました。ドックに戻ります。" :wait t)
    ;;     (ros::ros-info "start going back to the dock.")
    ;;     (auto-dock :n-trial n-dock-trial)
    ;;     (return-from go-to-kitchen nil)))
    (ros::ros-info "start going back to the dock.")
    (send *ri* :speak-jp "ドックに戻ります。" :wait t)
    (setq success-auto-dock (auto-dock :n-trial n-dock-trial))
    (when (and success-auto-dock (not initial-light-on))
      (unix::sleep 1)
      ;; The accuracy of Google Home recognition is better in English than in Japanese.
      ;; (send *ri* :speak-jp "オッケー、グーグル" :wait t)
      ;; (send *ri* :speak-jp "電気を消して" :wait t)
      (send *ri* :speak "OK, Google" :wait t)
      (send *ri* :speak "Turn off the light." :wait t))
    (unix::sleep 1)
    (and success-go-to-kitchen success-auto-dock)))

(defun go-to-elevator-front (floor_num)
  ;; go to the front of the elevator on the current floor
  (send *ri* :clear-costmap)
  (cond
   ((= floor_num 7) ;; 7F
      (send *ri* :move-to (make-coords :pos #f(1850 -30746 0) :rpy (float-vector -pi/2 0 0)) :frame-id "/map"))
   ((= floor_num 3) ;; 3F
      (send *ri* :move-to (make-coords :pos #f(1837 -30734 -0) :rpy (float-vector -pi/2 0 0)) :frame-id "/map"))
   ;; TODO other floors
   (t (ros::ros-error "choose another floor!"))))

(defun get-on-elevator ()
  (send *ri* :clear-costmap)
  (send *ri* :go-pos 3.0 0 180)
  (unix:sleep 1)
  (send *ri* :speak-jp "エレベーターに乗りました"))

(defun get-off-elevator (get_off_floor_num)
  ;; get off an elevator with changing maps 
  (let ((get_off_floor (format nil "/eng2/~Af" get_off_floor_num)))
    (change-floor get_off_floor :base-frame-name "/base_link")
    (send *ri* :speak-jp "マップを切り替えました" :wait t)
    (send *ri* :clear-costmap)
    ;; CHANGE TO MOVE-TO?
    (ros::service-call "/passthrough/stop" *pass-req* t)
    (send *ri* :go-pos 3.5 0 0)
    (unix:sleep 1)
    (send *ri* :speak-jp "エレベータからおりました" :wait t)))

(defun change-floor-fetch (floor_num)
  ;; fetch version of change-floor
  (let ((floor (format nil "/eng2/~Af" floor_num)))
    (change-floor floor :base-frame-name "/base_link")))
