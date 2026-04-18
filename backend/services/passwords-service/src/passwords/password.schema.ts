import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PasswordDocument = Password & Document;

// E2E-encrypted vault entry. The server never sees plaintext credentials.
// Client encrypts on device with a key derived from the master PIN (PBKDF2 / Argon2),
// then sends only ciphertext + iv. Server stores opaque bytes.
@Schema({ timestamps: true })
export class Password {
  @Prop({ required: true, index: true })
  userId!: string;

  @Prop({ required: true })
  platform!: string;

  @Prop({ required: true })
  label!: string;

  @Prop({ required: true })
  ciphertext!: string;

  @Prop({ required: true })
  iv!: string;

  @Prop()
  algorithm?: string;
}

export const PasswordSchema = SchemaFactory.createForClass(Password);
