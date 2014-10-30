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
		
		public static const PENDING:int = 0;
		public static const FULFILLED:int = 1;
		public static const REJECTED:int = 2;
		
		private var _state:int = PENDING;

		public function get state():int
		{
			return _state;
		}

		private var _result:* = null;

		public function get result():*
		{
			return _result;
		}

		private var _subscribers:Array = [];
		
		private function initializePromise(promise:Promise, resolver:Function):void {
			try {
				resolver(function resolvePromise(value:*):void {
					promise.resolve(value);
				}, function rejectPromise(reason:*):void {
					promise.reject(reason);
				});
			} catch(e:Error) {
				promise.reject(e);
			}
		}
		
		private function asap(callback:Function):void {
			setTimeout(function():void {
				callback();
			}, 1);
		}
		
		private function handleOwnThenable(thenable:Promise):void {
			var promise:Promise = this;
			
			if (thenable._state === FULFILLED) {
				promise.fullfill(thenable._result);
			} else if (promise._state === REJECTED) {
				promise.reject(thenable._result);
			} else {
				thenable.subscribe(undefined, function(value:*):void {
					promise.resolve(value);
				}, function(reason:*):void {
					promise.reject(reason);
				});
			}
		}
		
		internal function resolve(value:*):void {
			if (this === value) {
				reject(new TypeError("You cannot resolve a promise with itself"));
			} else if (value is Promise) {
				handleOwnThenable(value);
			} else {
				fullfill(value);
			}
		}

		internal function reject(reason:*):void {
			if (this._state !== PENDING) {
				return;
			}
			
			this._result = reason;
			this._state = REJECTED;
			
			asap(publish);
		}
		
		internal function fullfill(value:*):void {
			if (this._state !== PENDING) {
				return;
			}
			
			this._result = value;
			this._state = FULFILLED;
			
			if (this._subscribers.length > 0) {
				asap(publish);
			}
		}
		
		internal function subscribe(child:Promise, onFulfillment:Function, onRejection:Function):void {
			var subscribers:Array = this._subscribers;
			var length:int = subscribers.length;
			
			subscribers[length] = child;
			subscribers[length + FULFILLED] = onFulfillment;
			subscribers[length + REJECTED]  = onRejection;
			
			if (length === 0 && this._state) {
				asap(publish);
			}
		}
		
		private function publish():void {
			var subscribers:Array = this._subscribers;
			var settled:int = this._state;
			
			if (subscribers.length === 0) {
				return;
			}
			
			var child:Promise, callback:Function, detail:* = this._result;
			
			for (var i:int = 0; i < subscribers.length; i += 3) {
				child = subscribers[i];
				callback = subscribers[i + settled];
				
				if (child) {
					invokeCallback(settled, child, callback, detail);
				} else {
					callback(detail);
				}
			}
			
			this._subscribers.length = 0;
		}
		
		private function invokeCallback(settled:int, promise:Promise, callback:Function, detail:*):void {
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
					promise.reject(new TypeError('A promises callback cannot return that same promise.'));
					return;
				}
			} else {
				value = detail;
				succeeded = true;
			}
			
			if (promise._state !== PENDING) {
				// noop
			} else if (hasCallback && succeeded) {
				promise.resolve(value);
			} else if (failed) {
				promise.reject(error);
			} else if (settled === FULFILLED) {
				promise.fullfill(value);
			} else if (settled === REJECTED) {
				promise.reject(value);
			}
		}

		/**
		 * Promise.then处理函数，返回Promise对象
		 * @param onFulfillment 实现调用处理函数
		 * @param onRejection 拒绝调用处理函数
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public function then(onFulfillment:Function=null, onRejection:Function=null):Promise {
			var parent:Promise = this;
			var state:int = parent._state;
			
			if (state === FULFILLED && onFulfillment !== null || state === REJECTED && onRejection !== null) {
				return this;
			}
			
			var child:Promise = new Promise(noop);
			var result:* = parent._result;
			
			if (state) {
				var callback:Function = arguments[state - 1];
				asap(function():void{
					invokeCallback(state, child, callback, result);
				});
			} else {
				subscribe(child, onFulfillment, onRejection);
			}
			
			return child;
		}
		
		/**
		 * 拒绝处理，返回Promise对象
		 * @param onRejection 拒绝调用处理函数
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public function error(onRejection:Function):Promise {
			return this.then(null, onRejection);
		}
		
		/**
		 * <p>将多个异步操作Promise数组，包装成一个新的Promise对象</p>
		 * <p>当所有的异步操作成功是，新的Promise状态才变为Pormise.FULFILLED</p> 
		 * <p>只要其中一个异步操作失败，新的Promise状态就会变为Pormise.REJECTED</p> 
		 * @param entries 异步操作Promise数组
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public static function all(entries:Array):Promise {
			return new Enumerator(entries, true).promise;
		}
		
		/**
		 * 把对象包装成Promise对象
		 * @param object 对象
		 * @return Promise 返回Promise对象
		 * 
		 */		
		public static function resolve(object:*):Promise {
			if (object is Promise) {
				return Promise(object);
			} else {
				var promise:Promise = new Promise(noop);
				promise.resolve(object);
				return promise;
			}
		}
	}
}