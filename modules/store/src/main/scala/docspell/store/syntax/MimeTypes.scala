/*
 * Copyright 2020 Eike K. & Contributors
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

package docspell.store.syntax

import docspell.common._

object MimeTypes {

  implicit final class EmilMimeTypeOps(emt: emil.MimeType) {
    def toLocal: MimeType =
      MimeType(emt.primary, emt.sub, emt.params)
  }

  implicit final class DocspellMimeTypeOps(mt: MimeType) {
    def toEmil: emil.MimeType =
      emil.MimeType(mt.primary, mt.sub, mt.params)
  }
}
