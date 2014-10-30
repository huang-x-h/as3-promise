package com.dormouse
{
	import flash.utils.setTimeout;
	

	/**
	 * 约定对象
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
		
		private static const PENDING:Number = 0;
		private static const FULFILLED:Number = 1;
		private static const REJECTED:Number = 2;
		
		private var _state:Number = PENDING;
		private var _result:* = null;
		private var _subscribers:Array = [];
		
		private function initializePromise(promise:Promise, resolver:Function):void {
			try {
				resolver(function resolvePromise(value:*):void {
					resolve(promise, value);
				}, function rejectPromise(reason:*):void {
					reject(promise, reason);
				});
			} catch(e:Error) {
				reject(promise, e);
			}
		}
		
		private function asap(callback:Function, arg:*=null):void {
			setTimeout(function():void {
				callback(arg);
			}, 1);
		}
		
		private function handleOwnThenable(promise:Promise, thenable:Promise):void {
			if (thenable._state === FULFILLED) {
				fullfill(promise, thenable._result);
			} else if (promise._state === REJECTED) {
				reject(promise, thenable._result);
			} else {
				subscribe(thenable, undefined, function(value:*):void {
					resolve(promise, value);
				}, function(reason:*):void {
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
			
			if (promise._subscribers.length > 0) {
				asap(publish, promise);
			}
		}
			
		private function resolve(promise:Promise, value:*):void {
			if (promise === value) {
				reject(promise, new TypeError("You cannot resolve a promise with itself"));
			} else if (value is Promise) {
				handleOwnThenable(promise, value);
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
			
			asap(publish, promise);
		}
		
		private function publish(promise:Promise):void {
			var subscribers:Array = promise._subscribers;
			var settled:Number = promise._state;
			
			if (subscribers.length === 0) {
				return;
			}
			
			var child:Promise, callback:Function, detail:* = promise._result;
			
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
		
		private function subscribe(parent:Promise, child:Promise, onFulfillment:Function, onRejection:Function):void {
			var subscribers:Array = parent._subscribers;
			var length:Number = subscribers.length;
			
			subscribers[length] = child;
			subscribers[length + FULFILLED] = onFulfillment;
			subscribers[length + REJECTED]  = onRejection;
			
			if (length === 0 && parent._state) {
				asap(publish, parent);
			}
		}
		
		private function invokeCallback(settled:Number, promise:Promise, callback:Function, detail:*):void {
			var hasCallback:Boolean = callback !== null,
				value:*, error:*, succeeded:Boolean, failed:Boolean;
			
			if (hasCallback) {
				try {
					value = callback(detail);
					succeeded = true;
				} catch(e:Error) {
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

		/**
		 * 
		 * @param onFulfillment 实现调用处理函数
		 * @param onRejection 拒绝调用处理函数
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public function then(onFulfillment:Function=null, onRejection:Function=null):Promise {
			var parent:Promise = this;
			var state:Number = parent._state;
			
			if (state === FULFILLED && onFulfillment !== null || state === REJECTED && onRejection !== null) {
				return this;
			}
			
			var child:Promise = new Promise(function():void {});
			var result:* = parent._result;
			
			if (state) {
				var callback:Function = arguments[state - 1];
				asap(function():void{
					invokeCallback(state, child, callback, result);
				});
			} else {
				subscribe(parent, child, onFulfillment, onRejection);
			}
			
			return child;
		}
		
		/**
		 * 
		 * @param onRejection 拒绝调用处理函数
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public function error(onRejection:Function):Promise {
			return this.then(null, onRejection);
		}
		
		public static function all():Promise {
			
		}
	}
}