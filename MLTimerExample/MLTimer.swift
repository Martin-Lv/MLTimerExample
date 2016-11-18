//
//  MLTimer.swift
//  MLTimerExample
//
//  Created by 吕孟霖 on 2016/11/18.
//  Copyright © 2016年 Martin-Lv. All rights reserved.
//

import Foundation

final class MLTimer {
    typealias Handler = () -> Void
    ///timer interval in seconds
    var timeInterval:TimeInterval{
        didSet{
            configTimer()
        }
    }
    ///tolerance in seconds
    var tolerance:TimeInterval = 0{
        didSet {
            configTimer()
        }
    }
    var repeats:Bool{
        didSet{
            configTimer()
        }
    }
    
    var handler:Handler?
    
    private var mutex = pthread_mutex_t()
    private var _invalidated:Bool = false
    private var invalidated:Bool{
        get {
            pthread_mutex_lock(&mutex)
            defer{
                pthread_mutex_unlock(&mutex)
            }
            return _invalidated
        }
        set {
            pthread_mutex_lock(&mutex)
            _invalidated = newValue
            pthread_mutex_unlock(&mutex)
        }
    }
    
    private var timerQueue:DispatchQueue
    private var timer:DispatchSourceTimer
    
    init(timeInterval:TimeInterval, handler:@escaping Handler, repeats:Bool, dispatchQueue:DispatchQueue? = nil) {
        self.timeInterval = timeInterval
        self.handler = handler
        self.repeats = repeats
        self.timerQueue = dispatchQueue ?? DispatchQueue(label: "com.Timer")
        self.timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: self.timerQueue)
    }
    
    class func sheduleTimer(timeInterval:TimeInterval, handler:@escaping Handler, repeats:Bool, dispatchQueue:DispatchQueue)->MLTimer{
        let timer = MLTimer(timeInterval: timeInterval, handler: handler, repeats: repeats, dispatchQueue: dispatchQueue)
        timer.schedule()
        return timer
    }
    
    deinit {
        invalidate()
    }
    
    private func configTimer(){
        let firstFireTime = DispatchTime.now() + .microseconds(Int(self.timeInterval * 1000000))
        let leeway = DispatchTimeInterval.microseconds(Int(self.tolerance * 1000000))
        if repeats {
            timer.scheduleRepeating(deadline: firstFireTime, interval: self.timeInterval, leeway: leeway)
        }else{
            timer.scheduleOneshot(deadline: firstFireTime, leeway: leeway)
        }
    }
    
    private func timerFired(){
        if invalidated {
            return
        }
        handler?()
        if !repeats {
            invalidate()
        }
    }
    
    ///start timer.
    func schedule(){
        configTimer()
        timer.setEventHandler {[weak self] in
            self?.timerFired()
        }
        timer.resume()
    }
    
    ///fire the timer handler manually.
    func fire(){
        timerFired()
    }
    
    ///pause future execution of handler.
    func pause(){
        timerQueue.suspend()
    }
    
    ///resume future execution of handler.
    func resume(){
        timerQueue.resume()
    }
    
    ///invalidate timer. handler won't execute again.
    func invalidate(){
        if invalidated {
            return
        }
        invalidated = true
        timerQueue.async {[weak self] in
            guard let this = self else {return}
            this.timer.cancel()
            this.handler = nil
        }
    }
}

