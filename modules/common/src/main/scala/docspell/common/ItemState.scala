package docspell.common

import io.circe.{Decoder, Encoder}
import cats.data.NonEmptyList

sealed trait ItemState { self: Product =>

  final def name: String =
    productPrefix.toLowerCase

  def isValid: Boolean =
    ItemState.validStates.exists(_ == this)

  def isInvalid: Boolean =
    ItemState.invalidStates.exists(_ == this)
}

object ItemState {

  case object Premature  extends ItemState
  case object Processing extends ItemState
  case object Created    extends ItemState
  case object Confirmed  extends ItemState

  def fromString(str: String): Either[String, ItemState] =
    str.toLowerCase match {
      case "premature"  => Right(Premature)
      case "processing" => Right(Processing)
      case "created"    => Right(Created)
      case "confirmed"  => Right(Confirmed)
      case _            => Left(s"Invalid item state: $str")
    }

  val validStates: NonEmptyList[ItemState] =
    NonEmptyList.of(Created, Confirmed)

  val invalidStates: NonEmptyList[ItemState] =
    NonEmptyList.of(Premature, Processing)

  def unsafe(str: String): ItemState =
    fromString(str).fold(sys.error, identity)

  implicit val jsonDecoder: Decoder[ItemState] =
    Decoder.decodeString.emap(fromString)
  implicit val jsonEncoder: Encoder[ItemState] =
    Encoder.encodeString.contramap(_.name)
}
