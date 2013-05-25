app=angular.module('orderApp',['serviceModule'])


app.config(($routeProvider)->
  $routeProvider.when('/', templateUrl:'partials/main.html', controller:'mainCtrl')
                .when('/newOrder', templateUrl:'partials/newOrder.html', controller:'newOrderCtrl')
                .when('/sampleScan', templateUrl:'partials/sampleScan.html', controller:'scanCtrl')
                .otherwise(redirectTo:'/')
)
###
  Controllers
###
app.controller('mainCtrl', ($scope)->
  $scope.init=()->
    if Storage?
      if !localStorage.catalogFile?
        blackberry.ui.dialog.customAskAsync "An empty catalog file is being created"
        ,["OK"]
        ,(index)->
          try
            $scope.createFS()
          catch error
            alert(error)
        ,title:"Catalog file is not available"

  $scope.createFS=()->
    blackberry.io.sandbox=false;
    window.requestFileSystem  = window.requestFileSystem || window.webkitRequestFileSystem
    window.requestFileSystem(window.PERSISTENT, 5*1024*1024, $scope.initFS, $scope.errorFS)
  $scope.initFS=(fs)->
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
        ,$scope.errorFS
      ,$scope.errorFS
    ,$scope.errorFS
  $scope.errorFS=(err)->
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
)

app.controller('newOrderCtrl',($scope, $q, scannerService)->
  deferScanResult=false
  $scope.init=()->
    $scope.scanning=false
  $scope.startScan=()->
    scannerService.startScan((data)->
      $scope.scanning=false
      if data
        $scope.UPC=data
      $scope.$apply()
    )
    $scope.scanning=true
  $scope.stopScan=(data)->
    $scope.scanning=false
    scannerService.stopScan()

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
        , 5000)
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
)




















