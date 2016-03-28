//
//  ViewController.swift
//  Songs Downloader
//
//  Created by Sibi on 01/03/16.
//  Copyright © 2016 InApp. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController,NSURLSessionDownloadDelegate,NSURLSessionDelegate,AVAudioPlayerDelegate ,UITableViewDataSource,UITableViewDelegate{

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var songsTable: UITableView!
    @IBOutlet weak var searchTextHeight: NSLayoutConstraint!
    @IBOutlet weak var searchViewTop: NSLayoutConstraint!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var searchTFLeading: NSLayoutConstraint!
    @IBOutlet weak var searchTFTrailing: NSLayoutConstraint!
    @IBOutlet weak var searchViewHeight: NSLayoutConstraint!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progessIndicator: UIProgressView!
    @IBOutlet weak var seekBar: UISlider!
    
    var downloadTask: NSURLSessionDownloadTask!
    var backgroundSession: NSURLSession!
    var audioPlayer : AVAudioPlayer?
    var timer:NSTimer?
    var musicUrl:String?
    var songsList = NSArray()
    var currentId = -1

    //MARK:- Life cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupUI()
        configureSession()
        prepareSongsList()
    }
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        switch event!.subtype{
        case .RemoteControlPause:
                audioPlayer?.pause()
        case .RemoteControlPlay:
                audioPlayer?.play()
        case .RemoteControlStop:
                audioPlayer?.stop()
        case .RemoteControlBeginSeekingBackward:break
        case .RemoteControlTogglePlayPause:break
        default:break
        }
    }
    //MARK:_ Helper Methods
    func setupUI(){
        setupTable()
        setupSearchView()
        setupSeekBar()
    }
    func setupTable(){
        songsTable.tableFooterView = UIView(frame: CGRectZero)
        songsTable.allowsSelectionDuringEditing = true
        songsTable.rowHeight = 60
    }
    func setupSearchView(){
        searchViewHeight.constant = 39
        searchView.hidden = true
        progressView.hidden = true
        searchTextField.rightViewMode = .Always
        let frame = CGRectMake(0, 0, 30, searchTextField.bounds.size.height)
        let view = UIView(frame: frame)
        searchTextField.rightView = view
        searchViewTop.constant = -39
        let width = searchTextField.bounds.size.width
        searchTFLeading.constant = width/2 - 10
        searchTFTrailing.constant = width/2 - 10
    }
    func setupSeekBar(){
//        seekBar.setThumbImage(<#T##image: UIImage?##UIImage?#>, forState: .Normal)
    }
    func configureSession(){
        let backgroundSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("backgroundSession")
        backgroundSession = NSURLSession(configuration: backgroundSessionConfiguration, delegate: self, delegateQueue: nil)
    }
    
    func prepareSongsList(){
        let defaults = NSUserDefaults.standardUserDefaults()
        if let songs = defaults.valueForKey(kSongsList) as? NSArray{
            songsList = songs
        }
        
//        let songsQuery = MPMediaQuery()
//        let songs = songsQuery.items
        
        
    }
    func saveFileToDirectory(location:NSURL)->NSURL?{
        let directoryURL = getDirectoryURL()
        let fileManger = NSFileManager.defaultManager()
        
        let destinationFilename = downloadTask.originalRequest?.URL?.lastPathComponent
        let extendedName = "\(songsList.count+1)-\(destinationFilename!)"
        let destinationURL = directoryURL?.URLByAppendingPathComponent(extendedName)
        var isDir : ObjCBool = false
        
        if fileManger.fileExistsAtPath(directoryURL!.path!, isDirectory: &isDir){
            if isDir {
                // file exists and is a directory
                if !fileManger.fileExistsAtPath(destinationURL!.path!){
                    do{
                        try  fileManger.copyItemAtURL(location, toURL: destinationURL!)
                    } catch{
                        print("error while saving in existing path")
                    }
                }
            } else {
                // file exists and is not a directory
                do{
                    try fileManger.createDirectoryAtPath(directoryURL!.path!, withIntermediateDirectories: false, attributes: nil)
                }catch{
                    print("error while creating directory")
                }
            }
        }
        else {
            // file does not exist
            do{
                try fileManger.createDirectoryAtPath(directoryURL!.path!, withIntermediateDirectories: false, attributes: nil)
            }catch{
                print("error while creating directory")
            }
            
            do{
                try  fileManger.copyItemAtURL(location, toURL: destinationURL!)
            }catch{
                print("error while saving in new path")
            }
        }
        
        return destinationURL
    }
    
    
    func showRenameAlert(destinationURL:NSURL){
        let name =  downloadTask.originalRequest?.URL?.lastPathComponent
        let alert = UIAlertController(title: "Save file as", message: nil, preferredStyle: .Alert)

        alert.addTextFieldWithConfigurationHandler { (textfield) -> Void in
        }
        let saveAction = UIAlertAction(title: "Save", style: .Default) { (action) -> Void in
            if let tf = alert.textFields?.first{
                self.saveSongDetails(destinationURL, name: tf.text!)
            }
        }
        alert.addAction(saveAction)
        if let tf = alert.textFields?.first{
            tf.text = name
        }
        self.presentViewController(alert, animated: true, completion: nil)
    }
    func saveSongDetails(destinationURL:NSURL,name:String){
        
        let asset = AVAsset(URL: destinationURL)
        
        var dict : [String:AnyObject] = [
            kSongId : songsList.count+1,
            kSongName : name,
            kSongUrl : destinationURL.path!,
            kSongType: 0
            
        ]
        
        for data in asset.metadata{
            if let commonKey = data.commonKey{
                switch commonKey{
                case "title" :
                    if let name = data.value{
                         dict[kSongName] = name
                    }
                case "albumName" :
                    if let albumName = data.value{
                        dict[kSongAlbum] = albumName
                    }
                case "artist" :
                    if let artist = data.value{
                        dict[kSongArtist] = artist
                    }
                case "type" :
                    if let langauge = data.value{
                        dict[kSongLanguage] = langauge
                    }
                case "publisher" :
                    if let publisher = data.value{
                        dict[kSongPublisher] = publisher
                    }
                case "artwork" :
                    if let _ = data.value{
                        print("dfsdf")
//                        dict[kSongName] = artwork
                    }
                default : break
                }
            }
        }

        let array = NSMutableArray(array: songsList)
        array.addObject(dict)
        songsList = array
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(songsList, forKey: kSongsList)
        defaults.synchronize()
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.closeSearchViewAnimation()
            self.songsTable.reloadData()
            self.progressView.hidden = true
            self.searchView.hidden = true
            self.searchTextField.text = ""
        }

    }
    func playMusicFile(musicDict:NSDictionary){
        let fileUrl = musicDict[kSongUrl] as! String
          let fileManger = NSFileManager.defaultManager()
        if fileManger.fileExistsAtPath(fileUrl){
            print("file is")
        }
        else{
            print("no file")
        }
        let url = NSURL(fileURLWithPath: fileUrl)
        do{
            try audioPlayer = AVAudioPlayer(contentsOfURL: url)
        }catch{}
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                print("AVAudioSession Category Playback OK")
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                print("AVAudioSession is Active")
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        MPRemoteCommandCenter.sharedCommandCenter().seekForwardCommand.enabled = true
      print(audioPlayer?.duration)
        let infoDict = [
            MPMediaItemPropertyTitle:musicDict[kSongName]!,
            MPMediaItemPropertyPlaybackDuration:audioPlayer!.duration
        ]
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = infoDict
        seekBar.maximumValue = Float(audioPlayer!.duration)
        seekBar.minimumValue = 0

        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(ViewController.seekbarChaneged), userInfo: nil, repeats: true)
        timer?.fire()
    }
    func seekbarChaneged()  {
        seekBar.value = Float(audioPlayer!.currentTime)
        if seekBar.maximumValue == seekBar.value{
            timer?.invalidate()
        }
    }
    @IBAction func seekBarValueChanged(sender: UISlider) {
        audioPlayer?.currentTime = NSTimeInterval( sender.value)
    }
   
    
    func deleteFile(index:Int){
        
        let defaults = NSUserDefaults.standardUserDefaults()
        if let list = defaults.valueForKey(kSongsList) as? NSArray{
            let mArray = NSMutableArray(array: list)
            mArray.removeObjectAtIndex(index)
            defaults.setValue(mArray, forKey: kSongsList)
            defaults.synchronize()
            
            songsList = mArray
            songsTable.reloadData()
            
            if let urlStr = list[index][kSongUrl] as? String{
                let fileManger = NSFileManager.defaultManager()
                if fileManger.fileExistsAtPath(urlStr){
                    do{
                        if let url = NSURL(string: urlStr){
                            try fileManger.removeItemAtURL(url)
                        }
                    }
                    catch{}
                }
            }
        }
    }
    
    func getDirectoryURL()->NSURL?{
        let fileManger = NSFileManager.defaultManager()
        let URLs = fileManger.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let docDirectoryURL = URLs.first
        let directoryURL = docDirectoryURL?.URLByAppendingPathComponent(kSongsDirectory)
         return  directoryURL
    }
    
    //MARK: - Animation actions
    func showSearchViewAnimation(){
        searchView.hidden = false
        searchViewHeight.constant = 39
        self.searchViewTop.constant = 0
        UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
            self.view.layoutIfNeeded()
            
            }, completion: nil)
        
        self.searchTFLeading.constant = 10
        searchTFTrailing.constant = 10
        searchTextField.alpha = 0
        UIView.animateWithDuration(0.4, delay: 0.1, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
            self.view.layoutIfNeeded()
            self.searchTextField.alpha = 1
            
            }, completion: nil)
    }
    
    func closeSearchViewAnimation(){
        let width = searchTextField.bounds.size.width
        searchViewHeight.constant = 39
        self.searchTFLeading.constant = width/2
        searchTFTrailing.constant = width/2
        UIView.animateWithDuration(0.5, delay: 0, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
            self.view.layoutIfNeeded()
            }, completion: { (finished) -> Void in
                self.searchView.hidden = true
        })
        
        self.searchViewTop.constant = -39
        UIView.animateWithDuration(0.5, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
            self.view.layoutIfNeeded()
            
            }, completion: nil)
        
        
    }
    
    
    func downloadFileFromUrl(urlString:String){
        if let url = NSURL(string: urlString){
            downloadTask = self.backgroundSession.downloadTaskWithURL(url)
            downloadTask.resume()
        }
    }

    
    //MARK: - Button actions
    
    @IBAction func downloadButtonAction(sender: AnyObject) {
        searchTextField.resignFirstResponder()
        searchView.hidden = true
        progressView.hidden = false
        progessIndicator.progress = 0
        searchViewHeight.constant = 5
        downloadFileFromUrl(searchTextField.text!)
    }


    @IBAction func showTextField(sender: UIBarButtonItem) {
        if searchView.hidden{
           showSearchViewAnimation()
        }
        else{
           closeSearchViewAnimation()
        }

    }
    
    @IBAction func playButtonAction(sender: UIButton) {
        if let _ = audioPlayer{
            if self.audioPlayer!.playing{
                self.audioPlayer?.pause()
            }
            else{
                audioPlayer?.play()
            }
        }
       
    }
    
    //MARK: - URLSession delegate
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        saveFileToDirectory(location)
        showRenameAlert(location)
        

    }
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
            print("Unknown transfer size");
        }
        else{
            let progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.progessIndicator.progress = progress
            })
        }
    }
    
    //MARK: - Audio player delegate
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        
    }
    
    func audioPlayerBeginInterruption(player: AVAudioPlayer) {
        
    }
    
    func audioPlayerEndInterruption(player: AVAudioPlayer) {
        
    }
    
    //MARK: - Tableview datasource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songsList.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("AlbumCell") as! AlbumCell
      
        cell.titleLabel?.text = songsList[indexPath.row][kSongName] as? String
        cell.backgroundColor = UIColor.clearColor()
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let id = songsList[indexPath.row][kSongId] as! Int
        if let _ = audioPlayer{
            if currentId == id && audioPlayer!.playing {
                audioPlayer?.pause()
            }
            else if currentId == id{
                audioPlayer?.play()
            }
            else{
                playMusicFile(songsList[indexPath.row] as! NSDictionary)
            }
        }
        else{
            currentId = id
            playMusicFile(songsList[indexPath.row] as! NSDictionary)
           
        }
        
       
    }
    
    //MARK: - Tableview delegate
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete{
            
            deleteFile(indexPath.row)
           
        }
    }


}

