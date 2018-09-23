//
//  AllPagesViewController.swift
//  Kiwi
//
//  Created by Mark Hudnall on 3/10/15.
//  Copyright (c) 2015 Mark Hudnall. All rights reserved.
//

import UIKit

class AllPagesViewController: UITableViewController, UISearchDisplayDelegate {
    var indexer: Indexer!
    var files: [String]!
    var filteredFiles: [String] = []
    
    var selectedPermalink: String!
    
    @IBOutlet weak var searchBar: UISearchBar!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "home"),
            style: UIBarButtonItemStyle.plain,
            target: self,
            action: #selector(AllPagesViewController.navigateToHomePage)
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return self.filteredFiles.count
        } else {
            return self.files.count
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell : UITableViewCell
        var files = self.files
        if tableView == self.searchDisplayController!.searchResultsTableView {
            files = self.filteredFiles
            cell = self.tableView.dequeueReusableCell(withIdentifier: "pageCell")!
        } else {
            cell = self.tableView.dequeueReusableCell(withIdentifier: "pageCell", for: indexPath) 
        }
        let fileName = (files?[(indexPath as NSIndexPath).row])?.stringByDeletingPathExtension
        if let titleLabel = cell.viewWithTag(100) as? UILabel {
            titleLabel.text = Page.permalinkToName(permalink: fileName!)
        }
        if let detailLabel = cell.viewWithTag(101) as? UILabel {
            detailLabel.text = nil;
        }
        
        if let page = self.indexer.get(permalink: fileName!) {
            let characterSet = CharacterSet.whitespacesAndNewlines
            let components = page.rawContent.components(separatedBy: characterSet)
            let length = min(components.count, 30)
            let firstWords = components[0..<length].joined(separator: " ")
            if let detailLabel = cell.viewWithTag(101) as? UILabel {
                detailLabel.text = firstWords;
            }
        }

        // Configure the cell...

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedPermalink = self.files[(indexPath as NSIndexPath).row]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
    
    @objc func navigateToHomePage() {
        self.performSegue(withIdentifier: "NavigateToSelectedPage", sender: self)
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "NavigateToSelectedPage" {
            self.searchBar.resignFirstResponder()
            if let cell = sender as? UITableViewCell {
                if let textLabel = cell.viewWithTag(100) as? UILabel {
                self.selectedPermalink = Page.nameToPermalink(name: textLabel.text!)   
                }
            } else {
                self.selectedPermalink = "home"
            }
        }
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    
    // MARK: - Search
    
    func searchPages(_ searchText: String) {
        if searchText.characters.count >= 2 {
            let characterSet = CharacterSet.whitespacesAndNewlines
            let components = searchText.components(separatedBy: characterSet).map( { (word) in
                word + "*"
            })
            let searchTerms = components.joined(separator: " ")
            self.filteredFiles.removeAll(keepingCapacity: true)
            
            let matches = self.indexer.find(snippet: searchTerms)
            self.filteredFiles += matches
        }
    }
    
    func searchDisplayController(_ controller: UISearchDisplayController, shouldReloadTableForSearch searchString: String?) -> Bool {
        if let str = searchString {
            self.searchPages(str)
        }
        return true
    }


}
