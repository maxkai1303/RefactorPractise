//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class ListViewController: UITableViewController {
    // Step4 把詐騙的 Any 換成我們自己的 Type
	var items = [ItemViewModel]()
	
	var retryCount = 0
	var maxRetryCount = 0
	var shouldRetry = false
	
	var longDateStyle = false
	
	var fromReceivedTransfersScreen = false
	var fromSentTransfersScreen = false
	var fromCardsScreen = false
	var fromFriendsScreen = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
		if fromFriendsScreen {
			shouldRetry = true
			maxRetryCount = 2
			
			title = "Friends"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
			
		} else if fromCardsScreen {
			shouldRetry = false
			
			title = "Cards"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
			
		} else if fromSentTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = true

			navigationItem.title = "Sent"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendMoney))

		} else if fromReceivedTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = false
			
			navigationItem.title = "Received"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: self, action: #selector(requestMoney))
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
		if fromFriendsScreen {
			FriendsAPI.shared.loadFriends { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
                    // Step5.1 這裡取得 result 的的部分就會開始哭，一樣用 map 塞他的嘴，而且我們已知這裡是朋友，就直接用朋友轉
                    self?.handleAPIResult(result.map { items in
                        // Step5.2 把本來在 handleAPIResult 的是否捧油判斷整組搬來，這樣又省了一個 bool
                        // 而且也不用 as! [Friend]
                        if User.shared?.isPremium == true {
                            (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.save(items)
                        }
                        return items.map { item in
                            ItemViewModel(friend: item, selection: {
                                self?.select(friend: item)
                            })
                        }
                    })
				}
			}
		} else if fromCardsScreen {
			CardAPI.shared.loadCards { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
					self?.handleAPIResult(result.map { items in
                        items.map { item in
                            ItemViewModel(card: item, selection: {
                                self?.select(card: item)
                            })
                        }
                    })
				}
			}
		} else if fromSentTransfersScreen || fromReceivedTransfersScreen {
            TransfersAPI.shared.loadTransfers { [weak self, longDateStyle, fromSentTransfersScreen] result in
                DispatchQueue.mainAsyncIfNeeded {
                    self?.handleAPIResult(result.map { items in
                        // Step5.3 一樣把 handleAPIResult 關於 transfers 的東西搬來，就不用再去檢查 type
//                        if fromSentTransfersScreen {
//                            filteredItems = filteredItems.filter(\.isSender)
//                        } else {
//                            filteredItems = filteredItems.filter { !$0.isSender }
//                        }
                        // 把上面的 filter 移到這裡處理
                        items
                            .filter { fromSentTransfersScreen ? $0.isSender : !$0.isSender }
                            .map { item in
                            ItemViewModel(transfer: item,
                                          longDateStyle: longDateStyle,
                                          selection: {
                                self?.select(transfer: item)
                            })
                        }
                    })
                }
            }
        } else {
			fatalError("unknown context")
		}
	}
	// Step5 不要吃泛形
	private func handleAPIResult(_ result: Result<[ItemViewModel], Error>) {
		switch result {
		case let .success(items):
			self.retryCount = 0
			
            self.items = items
            // Step5.4 結果這邊就不需要再判斷了
//            self.items = filteredItems.map({ item in
//                // Step4.1 在這裡本來 filteredItems 是拿到 Any(102行) 我們改了型別後，他會在那邊哭，
//                // 所以我們在這邊 map 他，轉成我們想要的形狀
//                ItemViewModel(item, longDateStyle: longDateStyle, selection: { [weak self] in
//                    if let friend = item as? Friend {
//                        self?.select(friend: friend)
//                    } else if let card = item as? Card {
//                        self?.select(card: card)
//                    } else if let transfer = item as? Transfer {
//                        self?.select(transfer: transfer)
//                    } else {
//                        fatalError("unknown item: \(item)")
//                    }
//                })
//            })
			self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
			
		case let .failure(error):
			if shouldRetry && retryCount < maxRetryCount {
				retryCount += 1
				
				refresh()
				return
			}
			
			retryCount = 0
			
			if fromFriendsScreen && User.shared?.isPremium == true {
				(UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.loadFriends { [weak self] result in
					DispatchQueue.mainAsyncIfNeeded {
						switch result {
						case let .success(items):
                            // Step4.1.2 這裡也有一個會在那邊哭，但是這邊很明顯是拿 friend cache 所以我們直接轉朋友
                            self?.items = items.map({ item in
                                ItemViewModel(friend: item, selection: { [weak self] in
                                    self?.select(friend: item)
                                })
                            })
							self?.tableView.reloadData()
							
						case let .failure(error):
                            self?.showError(error: error)
						}
						self?.refreshControl?.endRefreshing()
					}
				}
			} else {
                self.showError(error: error)
				self.refreshControl?.endRefreshing()
			}
		}
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = items[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
		cell.configure(item)
		return cell
	}
	// Step3 移除這邊的 item 類型判斷，把東西移到我知道他是什麼 Type 的時候去判斷（在 ItemViewModel)
    // Step4.2 在上面取回資料的時候就先判斷，讓 item 是正確的型別就可以把判斷都拿掉了
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = items[indexPath.row]
        item.select()
	}
}

// Step1 讓 Cell 根本不需要判斷直接收要顯示什麼內容，把內容搬去 ItemViewModel init
extension UITableViewCell {
	func configure(_ vm: ItemViewModel) {
        textLabel?.text = vm.title
        detailTextLabel?.text = vm.subtitle
    }
}
// Step2 把選擇不同 Type 的部分拆開來個別呼叫
extension UIViewController {
    func select(friend: Friend) {
        let vc = FriendDetailsViewController()
        vc.friend = friend
        //        我們需要跟 navigationControler 解耦所以改用 show
//        navigationController?.pushViewController(vc, animated: true)
        show(vc, sender: self)
    }
    
    func select(card: Card) {
        let vc = CardDetailsViewController()
        vc.card = card
        show(vc, sender: self)
    }
    
    func select(transfer: Transfer) {
        let vc = TransferDetailsViewController()
        vc.transfer = transfer
        show(vc, sender: self)
    }
    
    @objc func addCard() {
        show(AddCardViewController(), sender: self)
    }
    
    @objc func addFriend() {
        show(AddFriendViewController(), sender: self)
    }
    
    @objc func sendMoney() {
        show(SendMoneyViewController(), sender: self)
    }
    
    @objc func requestMoney() {
        show(RequestMoneyViewController(), sender: self)
    }
    
    // 將重複行為另外獨立出來，使用爸爸給你的好接口脫離 presentation
    func showError(error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
//                self.presenterVC.present(alert, animated: true)
        self.showDetailViewController(alert, sender: self)
    }
}
