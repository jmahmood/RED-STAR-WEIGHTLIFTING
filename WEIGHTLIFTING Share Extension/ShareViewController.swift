//
//  ShareViewController.swift
//  WEIGHTLIFTING Share Extension
//
//  Created by Jawaad Mahmood on 2025-12-11.
//

import UIKit
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        extractFirstURL { url in
            if let url {
                let title = self.contentText.trimmingCharacters(in: .whitespacesAndNewlines)
                StoredLinkStore.shared.addSharedURL(url, title: title.isEmpty ? nil : title)
            }
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func extractFirstURL(completion: @escaping (URL?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        let providers = items.compactMap { $0.attachments }.flatMap { $0 }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    completion(item as? URL)
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let text = item as? String {
                        completion(URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        completion(nil)
                    }
                }
                return
            }
        }
        completion(nil)
    }
}
