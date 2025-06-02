(defpackage #:cl-swayipc
  (:use #:cl)
  (:import-from #:com.inuoe.jzon)
  (:export #:connection))

(in-package #:cl-swayipc)

(declaim (ftype (function () (values sb-bsd-sockets:socket &optional))))
(defun connect-to-sway ()
  "Returns a handle to the current Sway instance."
  (let ((swaysock-address (uiop:getenv "SWAYSOCK"))
        (socket (make-instance 'sb-bsd-sockets:local-socket
                               :type :stream)))
    (sb-bsd-sockets:socket-connect socket swaysock-address)))

(defclass connection ()
  ((magic-string :type list
                 :allocation :class
                 :initform '(#x69 #x33 #x2d #x69 #x70 #x63)
                 :reader magic-string)
   (socket :type sb-bsd-sockets:socket
           :initform (connect-to-sway)
           :reader socket))
  (:documentation "Object containing a handle to the current Sway instance."))

(defmethod initialize-instance :after ((conn connection) &key)
  (with-slots ((sock socket)) conn
    (sb-ext:finalize conn
                     (lambda ()
                       (sb-bsd-sockets:socket-close sock)))))

(defgeneric make-message (connection type &optional payload)
  (:documentation "Create a message of TYPE containing PAYLOAD understood by Sway IPC.")
  (:method ((conn connection) (type integer) &optional (payload ""))
    (with-slots ((magic magic-string)) conn
      (let* ((length-and-type
               (mapcan (lambda (num)
                         (loop for offset from 0 to 24 by 8
                               collect (logand num (ash #xff offset))))
                       (list (length payload) type)))
             (payload (map 'list #'char-code payload))
             (message (append magic length-and-type payload)))
        (map 'string #'code-char message)))))

(defgeneric send-message (connection message)
  (:documentation "Send MESSAGE to Sway IPC and receive a reply.")
  (:method ((conn connection) (message string))
    (with-slots ((sock socket)) conn
      (progn
        (sb-bsd-sockets:socket-send sock message
                                    (length message))
        (let* ((buf-size (* 8192 4))
               (reply (sb-bsd-sockets:socket-receive sock nil buf-size))
               (reply-start (position-if (lambda (c) (or (equal c #\[) (equal c #\{)))
                                         reply))
               (reply (subseq reply reply-start)))
          (com.inuoe.jzon:parse (remove #\Nul reply)))))))

(defgeneric run-command (connection payload)
  (:documentation "Parses and runs the PAYLOAD as sway commands.")
  (:method ((conn connection) (payload string))
    (send-message conn (make-message conn 0 payload))))

(defgeneric get-workspaces (connection)
  (:documentation "Retrieves the list of workspaces.")
  (:method ((conn connection))
    (send-message conn (make-message conn 1))))

(defgeneric subscribe (connection payload)
  (:documentation
   "Subscribe this IPC connection to the event types specified in the
    message payload. The payload should be a valid JSON array of events.")
  (:method ((conn connection) (payload list))
    (send-message conn (make-message conn 2))))

(defgeneric get-outputs (connection)
  (:documentation "Retrieve the list of outputs.")
  (:method ((conn connection))
    (send-message conn (make-message conn 3))))

(defgeneric get-tree (connection)
  (:documentation "Retrieve a JSON representation of the tree.")
  (:method ((conn connection))
    (send-message conn (make-message conn 4))))

(defgeneric get-marks (connection)
  (:documentation "Retrieve the currently set marks.")
  (:method ((conn connection))
    (send-message conn (make-message conn 5))))

(defgeneric get-bar-config (connection &optional payload)
  (:documentation
   "When sending without a PAYLOAD, this retrieves the list of configured
    bar IDs. When sent with a bar ID as the PAYLOAD, this retrieves the
    config associated with the specified by the bar ID in the
    PAYLOAD. This is used by swaybar, but could also be used for third
    party bars.")
  (:method ((conn connection) &optional (payload ""))
    (send-message conn (make-message conn 6 payload))))

(defgeneric get-version (connection)
  (:documentation "Retrieve version information about the sway process.")
  (:method ((conn connection))
    (send-message conn (make-message conn 7))))

(defgeneric get-binding-modes (connection)
  (:documentation "Retrieve the list of binding modes that are currently configured.")
  (:method ((conn connection))
    (send-message conn (make-message conn 8))))

(defgeneric get-config (connection)
  (:documentation "Retrieves the contents of the config that was last loaded.")
  (:method ((conn connection))
    (send-message conn (make-message conn 9))))

(defgeneric send-tick (connection &optional payload)
  (:documentation
   "Issues a tick event to all clients subscribing to the event to
    ensure that all events prior to the tick were received. If a PAYLOAD
    is given, it will be included in the tick event.")
  (:method ((conn connection) &optional (payload ""))
    (send-message conn (make-message conn 10 payload))))

(defgeneric get-binding-state (connection)
  (:documentation "Returns the currently active binding mode.")
  (:method ((conn connection))
    (send-message conn (make-message conn 12))))

(defgeneric get-inputs (connection)
  (:documentation "Retrieve a list of the input devices currently available.")
  (:method ((conn connection))
    (send-message conn (make-message conn 100))))

(defgeneric get-seats (connection)
  (:documentation "Retrieve a list of the seats currently configured.")
  (:method ((conn connection))
    (send-message conn (make-message conn 101))))
