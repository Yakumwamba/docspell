/*
 * Copyright 2020 Eike K. & Contributors
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

package docspell.store.file

import javax.sql.DataSource

import cats.effect._
import fs2._

import docspell.common._

import binny.{BinaryId, BinaryStore}
import doobie.Transactor

trait FileRepository[F[_]] {
  def getBytes(key: FileKey): Stream[F, Byte]

  def findMeta(key: FileKey): F[Option[FileMetadata]]

  def delete(key: FileKey): F[Unit]

  def save(
      collective: Ident,
      category: FileCategory,
      hint: MimeTypeHint
  ): Pipe[F, Byte, FileKey]
}

object FileRepository {

  def apply[F[_]: Async](
      xa: Transactor[F],
      ds: DataSource,
      cfg: FileRepositoryConfig
  ): FileRepository[F] = {
    val attrStore = new AttributeStore[F](xa)
    val log = docspell.logging.getLogger[F]
    val keyFun: FileKey => BinaryId = BinnyUtils.fileKeyToBinaryId
    val binStore: BinaryStore[F] = BinnyUtils.binaryStore(cfg, attrStore, ds, log)

    new FileRepositoryImpl[F](binStore, attrStore, keyFun)
  }
}
