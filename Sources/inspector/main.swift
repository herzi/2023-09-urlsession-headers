//
//  main.swift
//  2023-09-urlsession-headers
//
//  Created by Sven Herzberg on 2023-09-09.
//

import Logging
import ServiceLifecycle

let inspector = Inspector()

let servies = ServiceGroup(
    services: [inspector],
    gracefulShutdownSignals: [.sigterm],
    cancellationSignals: [.sigint],
    logger: Logger(label: "services")
)
try await servies.run()
