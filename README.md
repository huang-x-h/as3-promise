as3-promise
===========

参照[es6-promise](https://github.com/jakearchibald/es6-promise)修改成as3版本，实现在flex支持promise模式写法

# 基本用法 #

	Promise promise = new Promise(function(resolve:Function, reject:Function):void {
	  // succeed
	  resolve(value);
	  // or reject
	  reject(error);
	});
	
	promise.then(function(value:*):void {
	  // success
	}, function(value:*):void {
	  // failure
	});

Promise.then[示例](http://huang-x-h.github.io/as3-promise/PromiseExample.html)：

	//根据给定的url获取相应内容信息
	private function get(url:String):Promise {
		return new Promise(function(resolve:Function, reject:Function):void {
			var request:URLRequest = new URLRequest(url);
			var loader:URLLoader = new URLLoader(request);
			loader.addEventListener(Event.COMPLETE, function(e:Event):void {
				resolve(e.target.data);
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void {
				reject(e);
			});
		});
	}

	get("http://huang-x-h.github.io/as3-promise/menu.json").then(function(result:*):void {
		trace(result);
	});

# Chaining链接 #

`then`方法是可以链接套使用的，如果在`then`方法第一个处理函数返回内容时，会传递给下一个`then`处理

	get("menu.json").then(function(data:*):void {
	  return JSON.parse(data);
	}).then(function(json:*):void {
	  // proceed
	});

# 错误处理 #

提供`error`方法，等同于`then`方法的第二个参数函数处理

	get("menu.json").then(function(result:*):void {
	  //proceed;
	}).error(function(reason:*):void {
	  // failure
	});

等价于

	get("menu.json").then(function(result:*):void {
	  //proceed;
	}，function(reason:*):void {
	  // failure
	});

# Promise数组处理 #

提供`Promise.all`方法，等数组里所有的`promise`对象成功处理完成，才进行成功处理，当其中任何一个失败，直接进行错误处理。[示例](http://huang-x-h.github.io/as3-promise/PromiseAllExample.html)

	var promise1:Promise = get('directory.json');
	var promise2:Promise = get('menu.json');
	var promise3:Promise = get('portal.json');
	
	// 当三个json文件都获取完毕时，在进行赋值
	Promise.all([promise1, promise2, promise3]).then(function(result:Array):void {
		gridDirectory.dataProvider = new ArrayList(JSON.parse(result[0]) as Array);
		gridMenu.dataProvider = new ArrayList(JSON.parse(result[1]) as Array);
		gridPortal.dataProvider = new ArrayList(JSON.parse(result[2]) as Array);
	}).error(function(reason:*):void {
		Alert.show(reason);
	});