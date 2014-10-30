package com.dormouse
{
	/**
	 * 处理Promise数组，包装返回新的Promise对象
	 *  
	 * @author huang.xinghui
	 * 
	 */	
	public class Enumerator
	{
		public function Enumerator(input:Array, abortOnReject:Boolean) {
			this.initializeEnumerator(input, abortOnReject);
		}
		
		private var _promise:Promise;

		public function get promise():Promise
		{
			return _promise;
		}

		private var length:int;
		
		[ArrayElementType("com.dormouse.Promise")]
		private var _input:Array;
		
		private var _remaining:int;
		private var _abortOnReject:Boolean;
		private var _result:Array;
		
		private function initializeEnumerator(input:Array, abortOnReject:Boolean):void {
			this._promise = new Promise(function():void {});
			this._abortOnReject = abortOnReject;
			this._input = input;
			this.length = input.length;
			this._remaining = input.length;
			this._result = new Array(this.length);
			
			this.enumerate();
			if (this._remaining === 0) {
				this._promise.fullfill(this._result);
			}
		}
		
		private function enumerate():void {
			for (var i:int = 0; this._promise.state === Promise.PENDING && i < this.length; i++) {
				this.eachEntry(this._input[i], i);
			}
		}
		
		private function eachEntry(entry:Promise, i:int):void {
			if (entry.state !== Promise.PENDING) {
				this.settledAt(entry.state, i, entry.result);
			} else {
				this.willSettleAt(entry, i);
			}
		}
		
		private function settledAt(state:int, i:int, value:*):void {
			var promise:Promise = this._promise;
			
			if (promise.state === Promise.PENDING) {
				this._remaining--;
				
				if (this._abortOnReject && state === Promise.REJECTED) {
					promise.reject(value);
				} else {
					this._result[i] = value;
				}
			}
			
			if (this._remaining === 0) {
				promise.fullfill(this._result);
			}
		}
		
		private function willSettleAt(promise:Promise, i:int):void {
			var enumerator:Enumerator = this;
			
			promise.subscribe(null, function(value:*):void {
				enumerator.settledAt(Promise.FULFILLED, i, value);
			}, function(reason:*):void {
				enumerator.settledAt(Promise.REJECTED, i, reason);
			});
		}
		
	}
}