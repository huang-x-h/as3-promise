package com.promise
{
	import flash.utils.setTimeout;
	

	/**
	 * 
	 * @author huang.xinghui
	 * 
	 */	
	public class Promise
	{
		public function Promise(resolver:Function)
		{
			initializePromise(this, resolver);
		}
		
		private var PENDING:Number = 0;
		private var FULFILLED:Number = 1;
		private var REJECTED:Number = 2;
		
		private var _state:Number = PENDING;
		private var _result:* = null;
		private var _subscribers:Array = [];
		private var _onerror:Function;
		
		private function initializePromise(promise:Promise, resolver:Function):void {
			try {
				resolver(function resolvePromise(value){
					resolve(promise, value);
				}, function rejectPromise(reason) {
					reject(promise, reason);
				});
			} catch(e) {
				reject(promise, e);
			}
		}
		
		private function objectOrFunction(x:*):Boolean {
			return typeof x === "function" || (typeof x === "object" && x !== null); 
		}
		
		private function asap(callback:Function, arg:*=null):void {
			setTimeout(function():void {
				callback(arg);
			}, 1);
		}
		
		private function handleMaybeThenable(promise:Promise, maybeThenable:*):void {
			if (maybeThenable is Promise) {
				handleOwnThenable(promise, maybeThenable);
			} else {
//				var then = $$$internal$$getThen(maybeThenable);
//				
//				if (then === $$$internal$$GET_THEN_ERROR) {
//					reject(promise, $$$internal$$GET_THEN_ERROR.error);
//				} else if (then === undefined) {
//					fulfill(promise, maybeThenable);
//				} else if ($$utils$$isFunction(then)) {
//					$$$internal$$handleForeignThenable(promise, maybeThenable, then);
//				} else {
//					fulfill(promise, maybeThenable);
//				}
			}
		}
		
		private function handleOwnThenable(promise:Promise, thenable:Promise):void {
			if (thenable._state === FULFILLED) {
				fullfill(promise, thenable._result);
			} else if (promise._state === REJECTED) {
				reject(promise, thenable._result);
			} else {
				subscribe(thenable, undefined, function(value:*):void {
					resolve(promise, value);
				}, function(reason:*) {
					reject(promise, reason);
				});
			}
		}
		
		private function fullfill(promise:Promise, value:*):void {
			if (promise._state !== PENDING) {
				return;
			}
			
			promise._result = value;
			promise._state = FULFILLED;
			
			if (promise._subscribers.length === 0) {
			} else {
				asap(publish, promise);
			}
		}
			
		private function resolve(promise:Promise, value:*):void {
			if (promise === value) {
				reject(promise, new TypeError("You cannot resolve a promise with itself"));
			} else if (objectOrFunction(value)) {
				handleMaybeThenable(promise, value);
			} else {
				fullfill(promise, value);
			}
		}

		private function reject(promise:Promise, reason:*):void {
			if (promise._state !== PENDING) {
				return;
			}
			
			promise._result = reason;
			promise._state = REJECTED;
			
			asap(publishRejection, promise);
		}
		
		private function publishRejection(promise:Promise):void {
			
		}
		
		private function publish(promise:Promise):void {
			var subscribers:Array = promise._subscribers;
			var settled:Number = promise._state;
			
			if (subscribers.length === 0) {
				return;
			}
			
			var child, callback, detail = promise._result;
			
			for (var i:int = 0; i < subscribers.length; i += 3) {
				child = subscribers[i];
				callback = subscribers[i + settled];
				
				if (child) {
					invokeCallback(settled, child, callback, detail);
				} else {
					callback(detail);
				}
			}
			
			promise._subscribers.length = 0;
		}
		
		private function subscribe(parent, child, onFulfillment, onRejection):void {
			var subscribers = parent._subscribers;
			var length = subscribers.length;
			
			parent._onerror = null;
			
			subscribers[length] = child;
			subscribers[length + FULFILLED] = onFulfillment;
			subscribers[length + REJECTED]  = onRejection;
			
			if (length === 0 && parent._state) {
				asap(publish, parent);
			}
		}
		
		private function invokeCallback(settled, promise, callback, detail) {
			var hasCallback = callback !== null,
				value, error, succeeded, failed;
			
			if (hasCallback) {
				try {
					value = callback(detail);
					succeeded = true;
				} catch(e) {
					failed = true;
					error = e;
					value = null;
				}
				
				if (promise === value) {
					reject(promise, new TypeError('A promises callback cannot return that same promise.'));
					return;
				}
				
			} else {
				value = detail;
				succeeded = true;
			}
			
			if (promise._state !== PENDING) {
				// noop
			} else if (hasCallback && succeeded) {
				resolve(promise, value);
			} else if (failed) {
				reject(promise, error);
			} else if (settled === FULFILLED) {
				fullfill(promise, value);
			} else if (settled === REJECTED) {
				reject(promise, value);
			}
		}

		public function then(onFulfillment:Function=null, onRejection:Function=null):Promise {
			var parent:Promise = this;
			var state:Number = parent._state;
			
			if (state === FULFILLED && onFulfillment !== null || state === REJECTED && onRejection !== null) {
				return this;
			}
			
			parent._onerror = null;
			
			var child:Promise = new Promise(function():void {});
			var result:* = parent._result;
			
			if (state) {
				var callback = arguments[state - 1];
				asap(function(){
					invokeCallback(state, child, callback, result);
				});
			} else {
				subscribe(parent, child, onFulfillment, onRejection);
			}
			
			return child;
		}
		
		public function error(onRejection:Function):Promise {
			return this.then(null, onRejection);
		}
	}
}