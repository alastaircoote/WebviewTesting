//
//  Scripts.swift
//  WebviewTesting
//
//  Created by Alastair on 4/3/23.
//

import Foundation

// This code is shared between web and native and would only need to be written once.
// The web version is here:
// https://glitch.com/edit/#!/thunder-iced-earwig?path=public%2Factions.js%3A1%3A0

let actionsJavaScript = """
    async function checkServiceWorkerStatus() {
      const registration = await navigator.serviceWorker.getRegistration();
      return !!registration;
    }

    async function registerWorker() {
      await navigator.serviceWorker.register("sw.js", {
        scope: "/",
        type: "module",
      });
      await navigator.serviceWorker.ready;
    }

    async function removeWorker() {
      const registration = await navigator.serviceWorker.getRegistration();
      await registration.unregister();
      const cacheKeys = await caches.keys();
      for (const cache of cacheKeys) {
        await caches.delete(cache);
      }
    }

    async function sendMessageToWorker(message, feedbackListener) {
      const messageChannel = new MessageChannel();
      const promise = new Promise((fulfill, reject) => {
        messageChannel.port1.onmessage = function (msg) {
          if (msg.data.type === "feedback") {
            // If it's a feedback message it is intended to be sent before the final reply
            feedbackListener(msg.data);
          } else {
            // Otherwise it's the reply we want to send back to the native handler.
            fulfill(msg.data);
          }
        };
      });

      const registration = await navigator.serviceWorker.ready;
      registration.active.postMessage(message, [messageChannel.port2]);
      return promise;
    }

    /// CACHE

    async function checkCacheStatus() {
      const response = await sendMessageToWorker({
        action: "get-cache-size",
      });
      return response.sizes;
      
    }


    async function addToCache(sizeFeedbackListener) {
      const response = await sendMessageToWorker({
        action: "add-to-cache",
      }, function(feedbackItem) {
        sizeFeedbackListener(feedbackItem);
      });
      return response;
    }

    async function deleteCache() {
      const response = await sendMessageToWorker({
        action: "delete-cache",
      });
      return response;
    }
"""
