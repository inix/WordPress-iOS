class RevisionsTableViewController: UITableViewController {
    private var post: AbstractPost?
    private var manager: ShowRevisionsListManger?

    private lazy var tableViewHandler: WPTableViewHandler = {
        let tableViewHandler = WPTableViewHandler(tableView: self.tableView)
        tableViewHandler.cacheRowHeights = false
        tableViewHandler.delegate = self
        tableViewHandler.updateRowAnimation = .none
        return tableViewHandler
    }()

    private var tableViewFooter: RevisionsTableViewFooter {
        let footerView = RevisionsTableViewFooter(frame: CGRect(origin: .zero,
                                                                size: CGSize(width: tableView.frame.width,
                                                                             height: Sizes.sectionFooterHeight)))
        footerView.setFooterText(post?.dateCreated?.mediumStringWithTime())
        return footerView
    }


    convenience init(post: AbstractPost) {
        self.init()
        self.post = post
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPresenter()
        setupUI()

        tableViewHandler.refreshTableView()
        manager?.getRevisions()
    }
}


private extension RevisionsTableViewController {
    private func setupUI() {
        navigationItem.title = NSLocalizedString("History", comment: "Title of the post history screen")

        let cellNib = UINib(nibName: RevisionsTableViewCell.classNameWithoutNamespaces(),
                            bundle: Bundle(for: RevisionsTableViewCell.self))
        tableView.register(cellNib, forCellReuseIdentifier: RevisionsTableViewCell.reuseIdentifier)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshRevisions), for: .valueChanged)
        tableView.addSubview(refreshControl)

        self.refreshControl = refreshControl

        tableView.tableFooterView = tableViewFooter

        WPStyleGuide.configureColors(for: view, andTableView: tableView)
    }

    private func setupPresenter() {
        manager = ShowRevisionsListManger(post: post, attach: self)
    }

    @objc private func refreshRevisions() {
        manager?.getRevisions()
    }
}


extension RevisionsTableViewController: WPTableViewHandlerDelegate {
    func managedObjectContext() -> NSManagedObjectContext {
        return ContextManager.sharedInstance().mainContext
    }

    func fetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        guard let postId = post?.postID, let siteId = post?.blog.dotComID else {
            preconditionFailure("Expected a postId or a siteId")
        }

        let predicate = NSPredicate(format: "\(#keyPath(Revision.postId)) = %@ && \(#keyPath(Revision.siteId)) = %@", postId, siteId)
        let descriptor = NSSortDescriptor(key: #keyPath(Revision.postModifiedGmt), ascending: false)
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Revision.entityName())
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [descriptor]
        return fetchRequest
    }

    func sectionNameKeyPath() -> String {
        return #keyPath(Revision.revisionDateForSection)
    }

    func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        guard let cell = cell as? RevisionsTableViewCell else {
            preconditionFailure("The cell should be of class \(String(describing: RevisionsTableViewCell.self))")
        }

        let revision = getRevision(at: indexPath)
        cell.title = revision.revisionModifiedDate.shortTimeString()
        cell.subtitle = "author name"
        cell.totalAdd = revision.diff?.totalAdditions.intValue
        cell.totalDel = revision.diff?.totalDeletions.intValue
    }

    func getRevision(at indexPath: IndexPath) -> Revision {
        guard let revision = tableViewHandler.resultsController.object(at: indexPath) as? Revision else {
            preconditionFailure("Expected a Revision object.")
        }

        return revision
    }


    // MARK: Override delegate methodds

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Sizes.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Sizes.cellEstimatedRowHeight
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionInfo = tableViewHandler.resultsController.sections?[section],
            let headerView = Bundle.main.loadNibNamed(PageListSectionHeaderView.classNameWithoutNamespaces(),
                                                      owner: nil,
                                                      options: nil)?.first as? PageListSectionHeaderView else {
                return UIView()
        }

        headerView.setTite(sectionInfo.name)
        return headerView
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RevisionsTableViewCell.reuseIdentifier, for: indexPath) as? RevisionsTableViewCell else {
            preconditionFailure("The cell should be of class \(String(describing: RevisionsTableViewCell.self))")
        }

        configureCell(cell, at: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let revision = getRevision(at: indexPath)
        print("Select revision \(revision.revisionId.stringValue)")
    }
}


extension RevisionsTableViewController: RevisionsView {
    func stopLoading(success: Bool, error: Error?) {
        refreshControl?.endRefreshing()
        tableViewHandler.refreshTableView()
    }
}


private struct Sizes {
    static let sectionHeaderHeight = CGFloat(40.0)
    static let sectionFooterHeight = CGFloat(48.0)
    static let cellEstimatedRowHeight = CGFloat(60.0)
}


private extension Date {
    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .short
        return formatter
    }()

    func shortTimeString() -> String {
        return Date.shortTimeFormatter.string(from: self)
    }
}
