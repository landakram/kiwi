//
//  AllPagesViewController.swift
//  Memex
//
//  Created by Mark Hudnall on 3/10/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit
import Async
import YapDatabase

class AllPagesViewController: UITableViewController, UISearchDisplayDelegate {
    var wiki: Wiki!
    var files: [String]!
    var filteredFiles: [String] = []
    
    var selectedPermalink: String!
    
    var yapConnection: YapDatabaseConnection!
    
    @IBOutlet weak var searchBar: UISearchBar!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.files = self.wiki.files()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "home"),
            style: UIBarButtonItemStyle.Plain,
            target: self,
            action: Selector("navigateToHomePage")
        )
        
        self.yapConnection = Yap.sharedInstance.newConnection()
        self.yapConnection.beginLongLivedReadTransaction()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return self.filteredFiles.count
        } else {
            return self.files.count
        }
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("pageCell", forIndexPath: indexPath) as! UITableViewCell
        var files = self.files
        if tableView == self.searchDisplayController!.searchResultsTableView {
            files = self.filteredFiles
        }
        let fileName = files[indexPath.row].stringByDeletingPathExtension
        if let titleLabel = cell.viewWithTag(100) as? UILabel {
            titleLabel.text = Page.permalinkToName(fileName)
        }
        if let detailLabel = cell.viewWithTag(101) as? UILabel {
            detailLabel.text = nil;
        }
        
        self.yapConnection.readWithBlock({ (transaction) in
            if let page = transaction.objectForKey(fileName, inCollection: "pages") as? Page {
                    //                NSCharacterSet *delimiterCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                    //                NSArray *firstWords = [[str componentsSeparatedByCharactersInSet:delimiterCharacterSet] subarrayWithRange:wordRange];
                    let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
                    if let components = page.rawContent?.componentsSeparatedByCharactersInSet(characterSet) {
                        let length = min(components.count, 30)
                        let firstWords = " ".join(components[0..<length])
                        if let detailLabel = cell.viewWithTag(101) as? UILabel {
                            detailLabel.text = firstWords;
                        }
                    }
            }
            
            
        })
        // Configure the cell...

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.selectedPermalink = self.files[indexPath.row]
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 105.0;
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation
    
    func navigateToHomePage() {
        self.performSegueWithIdentifier("NavigateToSelectedPage", sender: self)
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "NavigateToSelectedPage" {
            self.searchBar.resignFirstResponder()
            if let cell = sender as? UITableViewCell {
                if let textLabel = cell.viewWithTag(100) as? UILabel {
                self.selectedPermalink = Page.nameToPermalink(textLabel.text!)   
                }
            } else {
                self.selectedPermalink = "home"
            }
        }
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    
    // MARK: - Search
    
    func searchPages(searchText: String) {
        if count(searchText) >= 2 {
            let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            let components = searchText.componentsSeparatedByCharactersInSet(characterSet).map( { (word) in
                word + "*"
            })
            let searchTerms = " ".join(components)
            self.filteredFiles.removeAll(keepCapacity: true)
            Yap.sharedInstance.newConnection().readWithBlock { (transaction) in
                transaction.ext("fts").enumerateKeysMatching(searchTerms, usingBlock: { (collection, key, stop) in
                    self.filteredFiles.append(key)
                })
            }
        }
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String!) -> Bool {
        self.searchPages(searchString)
        return true
    }


}
