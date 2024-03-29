###
Existing problems:
  Can't browse files in SDCard - wanted to check physical order info from /TakeOrder/orders
  Can't display image from SDCard - web view does not have permission
###

app=angular.module('orderApp',['serviceModule'])


app.config(($routeProvider)->
  $routeProvider.when('/', templateUrl:'partials/main.html', controller:'mainCtrl')
                .when('/newOrder', templateUrl:'partials/newOrder.html?random11', controller:'newOrderCtrl')
                .when('/sampleScan', templateUrl:'partials/sampleScan.html', controller:'scanCtrl')
                .otherwise(redirectTo:'/')
)
###
  Controllers
###
app.controller('mainCtrl', ($scope, $rootScope, catalogService)->
  $scope.init=()->
    catalogService.getCatalog (catalog)->
      $rootScope.catalog=catalog
      #alert("Loaded "+ catalog.length+" catalog items.")
)

app.controller('newOrderCtrl',($scope, $rootScope, scannerService, orderService)->
  deferScanResult=false

  $scope.init=()->
    $scope.scanning=false
    $scope.order=orderService.newOrder()
    $scope.order.items.push
      desc:"test description"
      price:"1.35"
      count:2
      code:"12345"
  $scope.startScan=()->
    scannerService.startScan((data)->
      $scope.scanning=false
      if data
        $scope.UPC=data
        item=_.find($rootScope.catalog,(item)->
          item.upc==$scope.UPC
        )
        if item?
          $scope.desc=item.desc
          $scope.price=item.price
          $scope.code=item.code
      $scope.$apply()
    )
    $scope.scanning=true
  $scope.stopScan=(data)->
    $scope.scanning=false
    scannerService.stopScan()
  $scope.addItem=()->
    $scope.order.items.push
      imagePath:"file:/"+blackberry.io.SDCard+"/TakeOrder/images/icon.png"
      desc:$scope.desc
      price:$scope.price
      code:$scope.code
      count:$scope.count
    # TODO Save order to file system (look for on update model).
    # TODO Prevent existing window accidentally
  $scope.updateItem=(item)->
    console.log(item)
    $scope.updatingItem=item
    $('#updateItemModal').foundation('reveal', 'open')
  true
)

app.controller("scanCtrl",['$scope','$location', ($scope, $location)->
     $scope.init=()->
      canvas = document.getElementById('myCanvas');
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      scanTimeout=null

      errorFound=(data)->
        console.log("Error : "+data.error + " description : "+ data.description);


      codeFound=(data)->
        console.log(data)
        $scope.stopBarcodeRead()
        blackberry.ui.toast.show("Detected : "+data.value)


      onStartRead=(data)->
        console.log("Started : "+data.successful);


      onStopRead=(data)->
        console.log("Stopped : " +data.successful);
      scanTimedOut=()->
        $scope.stopBarcodeRead()
        blackberry.ui.toast.show("No code scanned in 60 seconds. Stopping scanner.")


      $scope.startBarcodeRead=()->
        blackberry.app.lockOrientation("portrait-primary", false);
        community.barcodescanner.startRead(codeFound, errorFound, "myCanvas", onStartRead);
        scanTimeout=setTimeout(scanTimedOut, 60000);


      $scope.stopBarcodeRead=()->
        community.barcodescanner.stopRead(onStopRead, errorFound);
        blackberry.app.unlockOrientation();
        clearTimeout(scanTimeout)
        $location.path("/")
        $scope.$apply()



      $scope.startBarcodeRead()
])

###
Services
###
onStartRead:()->
angular.module('serviceModule',[]).factory('scannerService',($timeout)->

  scannerService=
    scanTimeout:false
    callback:false
    stopScan:()->
      blackberry.ui.toast.show("Stopping Scanner...")
      community.barcodescanner.stopRead(this.onStopRead, this.errorFound);
      #blackberry.app.unlockOrientation();
      $timeout.cancel(this.scanTimeout)
      this.callback(false)
    startScan:(callback)->
      try
        this.callback=callback
        foundCode=false
        canvas = document.getElementById('scanner')
        canvas.width = window.innerWidth
        canvas.height = window.innerHeight
        #blackberry.app.lockOrientation("portrait-primary", false);
        community.barcodescanner.startRead((data)->
          if !foundCode
            foundCode=true
            $timeout.cancel(scanTimeout)
            community.barcodescanner.stopRead(this.onStopRead, this.errorFound)
            #blackberry.app.unlockOrientation()
            callback(data.value)
        , this.errorFound, "scanner", this.onStartRead)
        scanTimeout=$timeout(()->
          blackberry.ui.toast.show("No code scanned in 60 seconds. Stopping scanner.")
          scannerService.stopScan()
        , 60000)
        this.scanTimeout=scanTimeout
      catch error
        alert(error)
    errorFound:(data)->
      alert("Error : "+data.error + " description : "+ data.description)

    codeFound:(data)->
      try
        blackberry.ui.toast.show("Detected : "+data.value)
        community.barcodescanner.stopRead(scannerService.onStopRead, scannerService.errorFound)
        #blackberry.app.unlockOrientation()
        clearTimeout(scannerService.scanTimeout)
        result.resolve(data.value);
      catch error
        alert(error)

    onStartRead:(data)->
      #blackberry.ui.toast.show("Started : "+data.successful)

    onStopRead:(data)->
      #blackberry.ui.toast.show("Stopped : "+data.successful)


  return scannerService
).factory("catalogService",()->
  callback:false
  getCatalog:(callback)->
    that=this
    this.callback=callback
    if Storage?
      blackberry.io.sandbox=false;
      if !localStorage.catalogFile?
        blackberry.ui.dialog.customAskAsync "An empty catalog file is being created"
        ,["OK"]
        ,(index)->
          try
            this.createFS()
          catch error
            alert(error)
        ,title:"Catalog file is not available"
      window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem
      window.requestFileSystem(window.PERSISTENT, 5*1024*1024, (fs)->
        fs.root.getFile blackberry.io.SDCard+'/TakeOrder/catalog.json'
        , create:false, exclusive:true
        , (fileEntry)->
          fileEntry.file (file)->
            reader=new FileReader()
            reader.onload=(e)->
              catalog=JSON.parse(e.target.result)
              try
                callback(catalog)
              catch error
                alert("catalog callback "+error)
            reader.onerror=(e)->
              alert("Error reading catalog file "+e.target.error)
            reader.readAsText(file, "UTF-8")
          ,that.errorFS
        ,that.errorFS
      ,that.errorFS)

  createFS:()->
    window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem
    window.requestFileSystem(window.PERSISTENT, 5*1024*1024, this.initFS, this.errorFS)

  #TODO: This might overwrite existing catalog.json if localStorage does not have catalog info
  initFS:(fs)->
    that=this
    fs.root.getDirectory blackberry.io.SDCard+'/TakeOrder'
    ,create:true
    ,(dirEntry)->
      fs.root.getFile blackberry.io.SDCard+'/TakeOrder/catalog.json'
      ,create:true
      ,(fileEntry)->
        fileEntry.createWriter (fileWriter)->
          window.BlobBuilder = window.BlobBuilder || window.WebKitBlobBuilder
          bb=new BlobBuilder()
          bb.append('{}')
          fileWriter.write bb.getBlob 'text/plain'
          localStorage.catalogFile=blackberry.io.SDCard+'/TakeOrder/catalog.json'
        ,that.errorFS
      ,that.errorFS
    ,that.errorFS

  errorFS:(err)->
    try
      msg="File System Error: "
      switch err.code
        when FileError.NOT_FOUND_ERR then msg+= 'File or directory not found'
        when FileError.NOT_READABLE_ERR then msg+= 'File or directory not readable'
        when FileError.PATH_EXISTS_ERR then msg+= 'File or directory already exists'
        when FileError.TYPE_MISMATCH_ERR then msg+='Invalid filetype'
        else
          msg+='unknown error'
    catch error
      alert(error)
    alert(msg)
).factory("orderService",()->
  listOrders_LEGACY:(callback)->
    alert("ListOrders")
    that=this
    blackberry.io.sandbox=false
    window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem
    #TODO try removing orders folder and see what happens
    window.requestFileSystem window.PERSISTENT, 1024*1024, (fs)->
      fs.root.getDirectory blackberry.io.SDCard+'/TakeOrder/orders/', create:true, (dirEntry)->
        dirReader=dirEntry.createReader()
        dirReader.readEntries (entries)->
          #TODO WHERE IS MY ENTRIES?????
          alert(entries)

          for entry in entries
            alert(entry.fullPath)
          #callback(orders)
        ,that.errorFS
      ,that.errorFS
    ,that.errorFS
  listOrders:(callback)->

  getOrder:(orderName)->

  newOrder:()->
    order={}
    if !localStorage.orderCounter?
      localStorage.orderCounter=1
    order.id=localStorage.orderCounter
    order.items=[]
    order
  deleteOrder:(orderName)->

  saveOrder:(order)->

  errorFS:(err)->
    try
      msg="File System Error: "
      switch err.code
        when FileError.NOT_FOUND_ERR then msg+= 'File or directory not found'
        when FileError.NOT_READABLE_ERR then msg+= 'File or directory not readable'
        when FileError.PATH_EXISTS_ERR then msg+= 'File or directory already exists'
        when FileError.TYPE_MISMATCH_ERR then msg+='Invalid filetype'
        when FileError.SECURITY_ERR then msg+='Security error'
        else
          msg+='unknown error'
    catch error
      alert(error)
    alert(msg)
)




















