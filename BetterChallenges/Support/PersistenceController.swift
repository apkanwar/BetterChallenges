import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        let persistentContainer = NSPersistentCloudKitContainer(name: "BetterChallengesModel")

        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store descriptions.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        #if !targetEnvironment(macCatalyst)
        let cloudIdentifier = "iCloud.RezPoint.BetterChallenges"
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudIdentifier)
        #endif

        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        var attemptedFallback = false

        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                if storeDescription.cloudKitContainerOptions != nil && !attemptedFallback {
                    attemptedFallback = true
                    print("CloudKit store failed to load (\(error)). Falling back to local Core Data store.")
                    storeDescription.cloudKitContainerOptions = nil
                    persistentContainer.loadPersistentStores { _, fallbackError in
                        if let fallbackError = fallbackError as NSError? {
                            fatalError("Unresolved Core Data error \(fallbackError), \(fallbackError.userInfo)")
                        }
                    }
                } else {
                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
                }
            }
        }

        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        container = persistentContainer
    }

    func save(context: NSManagedObjectContext? = nil) {
        let contextToSave = context ?? container.viewContext
        guard contextToSave.hasChanges else { return }
        do {
            try contextToSave.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
